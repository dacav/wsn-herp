
 #include <string.h>

 #include <Protocol.h>
 #include <OperationTable.h>
 #include <RoutingP.h>
 #include <Constants.h>

module RoutingP {

    provides {
        interface AMSend;
        interface Receive;
    }

    uses {
        interface OperationTable<struct route_state> as OpTab;
        interface RoutingTable as RTab;
        interface Protocol as Prot;
        interface Packet;
        interface AMPacket;
        interface TimerDelay;
        interface MultiTimer<struct route_state> as Timer;
        interface Pool<message_t> as PayloadPool;
        interface Queue<route_state_t> as RetryQueue;
        interface Queue<message_t *> as LoopBackQueue;
    }

}

implementation {

    event error_t OpTab.data_init (herp_oprec_t Op, route_state_t State)
    {
        memset(State, 0, sizeof(struct route_state));
        State->op.rec = Op;

        return SUCCESS;
    }

    event void OpTab.data_dispose (route_state_t State)
    {
        switch (State->op.type) {
            case EXPLORE:
                assert(State->explore.sched == NULL);
            case SEND:
                break;

            case NEW:
            default:
                assert(FALSE);
        }
    }

    static void start_timer (route_state_t State)
    {
        uint32_t T;
        rt_route_t *Propagate;

        assert(State->op.type == EXPLORE);
        assert(State->explore.sched == NULL);

        Propagate = &State->explore.to_dst;
        if (Propagate->first == AM_BROADCAST_ADDR) {
            T = call TimerDelay.for_any_node();
        } else {
            T = call TimerDelay.for_hops(Propagate->hops);
        }

        State->explore.sched = call Timer.schedule(T, State);
    }

    static void stop_timer (route_state_t State)
    {
        assert(State->op.type == EXPLORE);

        if (State->explore.sched == NULL) return;
        call Timer.nullify(State->explore.sched);
        State->explore.sched = NULL;
    }

    static void restart_timer (route_state_t State)
    {
        stop_timer(State);
        start_timer(State);
    }

    static inline herp_opid_t opid (route_state_t State)
    {
        return call OpTab.fetch_internal_id(State->op.rec);
    }

    static inline void del_op (route_state_t State)
    {
        call OpTab.free_record(State->op.rec);
    }

    static inline void close_op (route_state_t State, error_t E)
    {
        switch (State->op.type) {
            case SEND:
                signal AMSend.sendDone(State->send.msg, E);
                break;

            case EXPLORE:
                stop_timer(State);
                break;

            case NEW:
            default:
                assert(FALSE);
        }

        del_op(State);  // only allowed del_op() except in AMSend.send
    }

    static inline route_state_t new_op ()
    {
        herp_oprec_t Op = call OpTab.new_internal();
        return Op ? call OpTab.fetch_user_data(Op) : NULL;
    }

    static inline route_state_t int_op (herp_opid_t OpId)
    {
        herp_oprec_t Op = call OpTab.internal(OpId);
        assert(Op != NULL);
        return call OpTab.fetch_user_data(Op);
    }

    static inline route_state_t ext_op (const herp_opinfo_t *Info,
                                        bool MustExist)
    {
        herp_oprec_t Op = call OpTab.external(Info->from, Info->ext_opid,
                                              MustExist);
        return Op ? call OpTab.fetch_user_data(Op) : NULL;
    }

    task void loopback_task ()
    {
        assert(!call LoopBackQueue.empty());

        do {
            message_t *Msg = call LoopBackQueue.dequeue();
            message_t *Copy = call PayloadPool.get();
            error_t E;

            if (Copy == NULL) {
                E = EBUSY;
            } else {
                uint8_t Len;
                void *Payload;

                *Copy = *Msg;
                Len = call Packet.payloadLength(Copy);
                Payload = call Packet.getPayload(Copy, Len);

                call PayloadPool.put(
                    signal Receive.receive(Copy, Payload, Len)
                );
                E = SUCCESS;
            }

            signal AMSend.sendDone(Msg, E);

        } while (call LoopBackQueue.size() > 0);
    }

    static error_t loopback (message_t *Msg)
    {
        error_t E = call LoopBackQueue.enqueue(Msg);

        if (E == SUCCESS && call LoopBackQueue.size() == 1) {
            post loopback_task();
        }
        return E;
    }

    static error_t commit (route_state_t State, const rt_route_t *Route)
    {
        error_t E;

        switch (State->op.type) {
            case SEND:
                E = call Prot.send_data(State->send.msg, Route->first);
                if (E == SUCCESS) {
                    State->op.phase = CLOSE;
                }
                break;

            case EXPLORE:
                E = call Prot.fwd_build(&State->explore.info,
                                        State->explore.from_src.first,
                                        Route->hops);
                if (E == SUCCESS) {
                    State->op.phase = CLOSE;
                }
                break;
            case NEW:
            default:
                assert(FALSE);
        }

        return E;
    }

    static inline error_t fwd_explore (route_state_t State)
    {
        return call Prot.fwd_explore(&State->explore.info,
                                     State->explore.to_dst.first,
                                     State->explore.from_src.hops);
    }

    static error_t start_explore (route_state_t State)
    {
        rt_route_t *Route = &State->explore.to_dst;
        am_addr_t Target = State->explore.info.to;
        error_t E;

        switch (call RTab.get_route(Target, Route)) {
            case RT_FRESH:
                E = commit(State, Route);
                break;

            case RT_NONE:
                Route->first = AM_BROADCAST_ADDR;
                Route->hops = 0;
                /* Note: optimization here. Since
                    send_reach(x, y) -> send_verify(x, y, BROADCAST)
                 */
            case RT_VERIFY:
                E = fwd_explore(State);
                if (E == SUCCESS) {
                    call RTab.promise_route(Target);
                    State->op.phase = WAIT_BUILD;
                    start_timer(State);
                }
                break;

            case RT_WORKING:
                State->op.phase = WAIT_ROUTE;
                E = call RTab.enqueue_for(Target, opid(State)) == RT_OK ?
                    SUCCESS : FAIL;
                break;

            default:
                assert(FALSE);
        }

        return E;
    }

    static error_t new_explore (am_addr_t Target)
    {
        route_state_t State;
        error_t E;

        State = new_op();
        if (State == NULL) return ENOMEM;

        State->op.type = EXPLORE;

        opinfo_init(&State->explore.info, opid(State), TOS_NODE_ID,
                    Target);
        State->explore.from_src.first = TOS_NODE_ID;
        State->explore.from_src.hops = 0;

        E = start_explore(State);
        if (E != SUCCESS) {
            close_op(State, E);
        }
        return E;
    }

    static error_t start_send (route_state_t State);

    task void send_retry_task ()
    {
        route_state_t State;
        error_t E;

        assert(call RetryQueue.empty() == FALSE);
        State = call RetryQueue.dequeue();

        E = FAIL;
        if (State->send.retry) {
            E = start_send(State);
        }
        if (E != SUCCESS) {
            close_op(State, E);
        }
    }

    static error_t retry (route_state_t State)
    {
        error_t E;

        assert(State->send.retry > 0);
        E = call RetryQueue.enqueue(State);
        if (E == SUCCESS) {
            State->send.retry --;
            post send_retry_task();
        }
        return E;
    }

    static error_t start_send (route_state_t State)
    {
        rt_route_t Route;
        error_t E;
        am_addr_t Addr = State->send.to;

        switch (call RTab.get_route(Addr, &Route)) {
            case RT_FRESH:
                E = commit(State, &Route);
                break;

            case RT_NONE:
            case RT_VERIFY:
                E = new_explore(Addr);
                if (E == SUCCESS) {
            case RT_WORKING:
                    if (call RTab.enqueue_for(Addr, opid(State)) != RT_OK) {
                        E = retry(State);
                    }
                }
                break;

            default:
                assert(FALSE);
        }

        return E;
    }


    command error_t AMSend.send (am_addr_t Addr, message_t *Msg, uint8_t Len)
    {
        route_state_t State;
        error_t E;

        call Packet.setPayloadLength(Msg, Len);

        if (Addr == TOS_NODE_ID) return loopback(Msg);

        State = new_op();
        if (State == NULL) return ENOMEM;
        State->op.type = SEND;

        E = call Prot.init_user_msg(Msg, opid(State), Addr);

        if (E == SUCCESS) {
            State->send.msg = Msg;
            State->send.to = Addr;
            State->send.retry = HERP_MAX_RETRY;

            E = start_send(State);
        }

        if (E != SUCCESS) {
            del_op(State);  // only this del_op() can be called directly
        }

        return E;
    }

    static void prot_done (route_state_t State, error_t E)
    {
        if (State->op.phase == CLOSE || E != SUCCESS) {

            // "phase!=CLOSE implies (type==EXPLORE and E!=SUCCESS)"
            assert(State->op.phase == CLOSE ||
                   (State->op.type == EXPLORE && E != SUCCESS));

            close_op(State, E);
        }
    }

    event void Prot.done_local (herp_opid_t OpId, error_t E)
    {
        herp_oprec_t Op = call OpTab.internal(OpId);
        if (Op) prot_done(call OpTab.fetch_user_data(Op), E);
    }

    event void Prot.done_remote (am_addr_t Own, herp_opid_t ExtOpId,
                                 error_t E)
    {
        herp_oprec_t Op = call OpTab.external(Own, ExtOpId, TRUE);
        if (Op) prot_done(call OpTab.fetch_user_data(Op), E);
    }

    event void Timer.fired (route_state_t State)
    {
        am_addr_t Target, FirstHop;

        assert(State->op.type == EXPLORE &&
               State->op.phase == WAIT_BUILD &&
               State->explore.sched != NULL);

        Target = State->explore.info.to;
        FirstHop = State->explore.to_dst.first;

        if (FirstHop != AM_BROADCAST_ADDR) {
            /* I had a route to check */
            call RTab.drop_route(Target, FirstHop);
        } else {
            call RTab.fail_promise(Target);
        }
    }

    static bool update_backpath (route_state_t State, am_addr_t Prev,
                                 uint16_t HopsFromSrc)
    {
        if (HopsFromSrc >= State->explore.from_src.hops) return FALSE;

        /* Found a better back-path! */
        State->explore.from_src.first = Prev;
        State->explore.from_src.hops = HopsFromSrc;
        return TRUE;
    }

    event void Prot.got_explore (const herp_opinfo_t *Info, am_addr_t Prev,
                                 uint16_t HopsFromSrc)
    {
        route_state_t State = ext_op(Info, FALSE);
        error_t E;
        if (State == NULL) return;

        switch (State->op.type) {

            case NEW:
                State->op.type = EXPLORE;
                opinfo_copy(&State->explore.info, Info);
                State->explore.from_src.first = Prev;
                State->explore.from_src.hops = HopsFromSrc;


                E = start_explore(State);
                if (E != SUCCESS) {
                    close_op(State, E);
                }
                break;

            case EXPLORE:
                assert(opinfo_equal(Info, &State->explore.info));
                if (Info->from == TOS_NODE_ID) {
                    assert(State->explore.from_src.first == TOS_NODE_ID);
                    return; // ignore our own explores
                }
                switch (State->op.phase) {
                    case CLOSE:
                        return; // ignore new explores for to-be-closed

                    case WAIT_BUILD:
                        if (update_backpath(State, Prev, HopsFromSrc)) {
                            // re-forward explore, but failures are not
                            // fatal.
                            if (fwd_explore(State) == SUCCESS) {
                                restart_timer(State);
                            }
                        }
                        break;

                    case WAIT_ROUTE:
                        update_backpath(State, Prev, HopsFromSrc);
                        break;

                    case START:
                    default:
                        assert(FALSE);
                }
                break;

            case SEND:
                return; // ignore explore

            default:
                assert(NULL);
        }
    }

    static inline void opportunistic (am_addr_t Prev)
    {
        rt_route_t Route = {
            .first = Prev,
            .hops = 1
        };

        call RTab.add_route(Prev, &Route);
    }

    event void Prot.got_build (const herp_opinfo_t *Info, am_addr_t Prev,
                               uint16_t HopsFromDst)
    {
        route_state_t State;
        error_t E;
        rt_route_t Route = {
            .first = Prev,
            .hops = HopsFromDst
        };

        call RTab.add_route(Info->to, &Route);
        if (Prev != Info->to) {
            opportunistic(Prev);
        }

        State = ext_op(Info, FALSE);

        if (State && State->op.type == EXPLORE
                  && State->op.phase == WAIT_BUILD) {
            assert(State->explore.sched);
            stop_timer(State);
            E = start_explore(State);
            if (E != SUCCESS) {
                close_op(State, E);
            }
        } else {
            assert(FALSE);  // TODO: remove. This may happen with byzantines
        }
    }

    event void RTab.deliver (herp_opid_t OpId, rt_res_t Res, am_addr_t To,
                             const rt_route_t *Route)
    {
        route_state_t State = int_op(OpId);
        error_t E;

        switch (State->op.type) {
            case SEND:
                assert(To == State->send.to);
                if (Res == RT_FRESH) {
                    E = commit(State, Route);
                    if (E != SUCCESS) {
                        close_op(State, E);
                    }
                } else {
                    retry(State);
                }
                break;

            case EXPLORE:
                assert(State->op.phase == WAIT_ROUTE);
                assert(To == State->explore.info.to);
                switch (Res) {
                    case RT_NONE:
                        E = FAIL;
                    case RT_FRESH:
                        E = commit(State, Route);
                        break;
                    case RT_VERIFY:
                        E = start_explore(State);
                        break;
                    default:
                        assert(FALSE);
                }
                if (E != SUCCESS) {
                    close_op(State, E);
                }
                break;

            case NEW:
            default:
                assert(FALSE);
        }
    }

    command void * AMSend.getPayload(message_t *Msg, uint8_t Len)
    {
        return call Packet.getPayload(Msg, Len);
    }

    command uint8_t AMSend.maxPayloadLength()
    {
        return call Packet.maxPayloadLength();
    }

    command error_t AMSend.cancel(message_t *Msg)
    {
        return FAIL;
    }

    event message_t * Prot.got_payload (const herp_opinfo_t *Info,
                                        message_t *Msg, uint8_t Len)
    {
        return Msg;
    }

}

