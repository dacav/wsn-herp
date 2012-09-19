
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
        interface RoutingTable as RTab[herp_opid_t];
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

    event error_t OpTab.data_init (route_state_t Routing)
    {
        memset((void *)Routing, 0, sizeof(struct route_state));
        return SUCCESS;
    }

    static inline herp_opid_t opid (route_state_t State)
    {
        return call OpTab.fetch_internal_id(State->op_rec);
    }

    event void OpTab.data_dispose (route_state_t State)
    {
        switch (State->op.type) {

            case EXPLORE:
                if (State->explore.job) {
                    call RTab.drop_job[opid(State)](State->explore.job);
                }

                if (State->explore.sched) {
                    call Timer.nullify(State->explore.sched);
                }
                break;

            case PAYLOAD:
                if (State->payload.msg) {
                    call PayloadPool.put(State->payload.msg);
                }
            default:
        }
    }

    static error_t send_fetch_route (route_state_t State);

    static route_state_t new_op ()
    {
        herp_oprec_t Op;
        route_state_t State;

        Op = call OpTab.new_internal();
        if (Op == NULL) return NULL;

        State = call OpTab.fetch_user_data(Op);
        assert(State->op.type == NEW &&
               State->op.phase == START);
        State->op_rec = Op;

        return State;
    }

    static inline void del_op (route_state_t State)
    {
        call OpTab.free_record(State->op_rec);
    }

    static inline error_t fwd_explore (route_state_t State)
    {
        return call Prot.fwd_explore(
                    &State->explore.info,
                    State->explore.propagate,
                    State->explore.hops_from_src
               );
    }

    static error_t run_explore (route_state_t State)
    {
        herp_rtentry_t Entry;
        herp_rtroute_t Route = NULL;
        explore_state_t *Explore;
        error_t E;
        herp_opid_t OpId = opid(State);

        switch (call RTab.get_route[OpId](State->send.target, &Entry)) {
            case HERP_RT_ERROR:
                return ENOMEM;

            case HERP_RT_SUBSCRIBED:
                /* Waiting the next-hop. */
                State->op.phase = WAIT_ROUTE;
                return SUCCESS;

            case HERP_RT_VERIFY:
                Route = call RTab.get_job[OpId](Entry);
                if (Route == NULL) return ERETRY;
            case HERP_RT_REACH:
                break;

            default:
                assert(0);
        };

        State->op.phase = WAIT_PROT;
        Explore = &State->explore;
        Explore->job = Route;
        Explore->propagate = (Route == NULL)
                           ? AM_BROADCAST_ADDR
                           : (call RTab.get_hop[OpId](Route))->first_hop;

        if (Explore->info.from == TOS_NODE_ID) {
            /* This is a local operation */
            assert(Explore->info.from == TOS_NODE_ID);
            if (Explore->propagate == AM_BROADCAST_ADDR) {
                E = call Prot.send_reach(OpId, Explore->info.to);
            } else {
                E = call Prot.send_verify(OpId, Explore->info.to,
                                          Explore->propagate);
            }
        } else {
            /* This is a remote operation */
            E = fwd_explore(State);
        }

        return E;
    }

    static error_t new_explore (am_addr_t Target, herp_opid_t OnBehalf)
    {
        route_state_t State;
        error_t Ret;

        State = new_op();
        if (State == NULL) return ENOMEM;

        State->op.type = EXPLORE;
        State->explore.prev = TOS_NODE_ID;

        opinfo_init(&State->explore.info, OnBehalf, TOS_NODE_ID, Target);

        Ret = run_explore(State);
        if (Ret != SUCCESS) {
            del_op(State);
        }
        return Ret;
    }

    task void send_retry_task ()
    {
        route_state_t State;
        error_t E = FAIL;

        assert(call RetryQueue.empty() == FALSE);
        State = call RetryQueue.dequeue();

        if (State->send.retry) {
            E = send_fetch_route(State);
        }
        if (E != SUCCESS) {
            signal AMSend.sendDone(State->send.msg, E);
            del_op(State);
        }
    }

    static error_t retry (route_state_t State)
    {
        error_t Ret;

        assert(State->send.retry > 0);
        Ret = call RetryQueue.enqueue(State);
        if (Ret == SUCCESS) {
            State->send.retry --;
            post send_retry_task();
        }
        return Ret;
    }

    static error_t send_fetch_route (route_state_t State)
    {
        herp_rtentry_t Entry;

        switch (call RTab.get_route[opid(State)](State->send.target,
                                                 &Entry)) {
            case HERP_RT_ERROR:
                return ENOMEM;

            case HERP_RT_SUBSCRIBED:
                /* Waiting the next-hop. */
                State->op.phase = WAIT_ROUTE;
                return SUCCESS;

            case HERP_RT_VERIFY:
            case HERP_RT_REACH:
                /* Start a reach operation and retry later. */
                return new_explore(State->send.target, opid(State));

            default:
                assert(0);

        };
    }

    task void loopback_task ()
    {
        assert(!call LoopBackQueue.empty());

        do {
            message_t *Msg = call LoopBackQueue.dequeue();
            uint8_t Len = call Packet.payloadLength(Msg);
            void *Payload = call Packet.getPayload(Msg, Len);

            signal Receive.receive(Msg, Payload, Len);
            signal AMSend.sendDone(Msg, SUCCESS);

        } while (call LoopBackQueue.size() > 0);
    }

    static error_t loopback (message_t *Msg)
    {
        error_t Ret = call LoopBackQueue.enqueue(Msg);

        if (Ret == SUCCESS && call LoopBackQueue.size() == 1) {
            post loopback_task();
        }
        return Ret;
    }

    command error_t AMSend.send (am_addr_t Addr, message_t *Msg, uint8_t Len)
    {
        route_state_t State;
        error_t RetVal;

        call Packet.setPayloadLength(Msg, Len);

        if (Addr == TOS_NODE_ID) {
            return loopback(Msg);
        }

        State = new_op();
        if (State == NULL) return ENOMEM;

        assert(State->op.type == NEW &&
               State->op.phase == START);

        /* -- Initialization ------------------------------------------ */

        State->op.type = SEND;

        RetVal = call Prot.init_user_msg(Msg, opid(State), Addr);
        if (RetVal != SUCCESS) {
            del_op(State);
            return RetVal;
        }

        State->send.msg = Msg;
        State->send.target = Addr;
        State->send.retry = HERP_MAX_RETRY;

        /* -- Start the send process ---------------------------------- */

        RetVal = send_fetch_route(State);
        if (RetVal != SUCCESS) {
            del_op(State);
        }
        return RetVal;
    }

    static void resume_send (herp_opid_t OpId)
    {
        herp_oprec_t Op = call OpTab.internal(OpId);

        assert(Op != NULL);
        retry( call OpTab.fetch_user_data(Op) );
    }

    event void Timer.fired (route_state_t State)
    {
        assert(State->op.type == EXPLORE);
        assert(State->explore.sched != NULL);

        State->explore.sched = NULL;
        if (State->explore.job != NULL) {
            call RTab.drop_route[opid(State)](State->explore.job);
            State->explore.job = NULL;
        }

        if (State->explore.prev == TOS_NODE_ID) {
            State->explore.prev = AM_BROADCAST_ADDR;
            resume_send(State->explore.info.ext_opid);
        }
        del_op(State);
    }

    static void set_explore_data (explore_state_t *Explore,
                                  am_addr_t Prev,
                                  uint16_t HopsFromSrc,
                                  const herp_opinfo_t *Info)
    {
        Explore->prev = Prev;
        Explore->hops_from_src = HopsFromSrc;
        opinfo_copy(&Explore->info, Info);
    }

    static void start_timer (route_state_t State)
    {
        uint32_t T;

        assert(State->op.type == EXPLORE);
        assert(State->explore.sched == NULL);

        if (State->explore.job == NULL) {
            T = call TimerDelay.for_any_node();
        } else {
            const herp_rthop_t *Hop;

            Hop = call RTab.get_hop[opid(State)](State->explore.job);
            T = call TimerDelay.for_hops(Hop->n_hops);
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

    event void Prot.got_explore (const herp_opinfo_t *Info, am_addr_t Prev,
                                 uint16_t HopsFromSrc)
    {
        herp_oprec_t Op;
        route_state_t State;
        explore_state_t *Explore;
        error_t E;

        Op = call OpTab.external(Info->from, Info->ext_opid, FALSE);
        if (Op == NULL) return;

        State = call OpTab.fetch_user_data(Op);
        Explore = &State->explore;

        switch (State->op.type) {

            case NEW:
                State->op_rec = Op;
                if (Info->to == TOS_NODE_ID) {
                    State->op.type = BUILD;
                    State->op.phase = WAIT_JOB;
                    E = call Prot.send_build(opid(State), Info, Prev);
                } else {
                    State->op.type = EXPLORE;
                    set_explore_data(Explore, Prev, HopsFromSrc, Info);
                    E = run_explore(State);
                }
                if (E != SUCCESS) {
                    del_op(State);
                }
                break;

            case EXPLORE:

                /* Exclude byzantine and useless cases */
                if (State->explore.prev == TOS_NODE_ID) return;
                if (HopsFromSrc >= Explore->hops_from_src) return;

                set_explore_data(Explore, Prev, HopsFromSrc, Info);
                if (State->op.phase != WAIT_ROUTE) {
                    if (fwd_explore(State) == SUCCESS) {
                        restart_timer(State);
                    }
                }

                break;

            /* Those cases could happen only because of late explore
             * messages and byzantine behaviors.
             *
             * They've been tested to be possible (with assertions), now
             * they can be ignored safely.
             */
            case COLLECT:
            case SEND:
            case PAYLOAD:
            default:
                return;
        }
    }

    static void prot_done (route_state_t State)
    {
        explore_state_t *Explore;

        switch (State->op.type) {

            case EXPLORE:
                /* Next code chunk */
                break;

            case SEND:
                signal AMSend.sendDone(State->send.msg, SUCCESS);
            case PAYLOAD:
            case COLLECT:
            case BUILD:
                assert(State->op.phase == WAIT_JOB);
                del_op(State);
                return;

            default:
                assert(0);
        }

        Explore = &State->explore;
        switch (State->op.phase) {

            case WAIT_PROT:
                start_timer(State);
                State->op.phase = WAIT_BUILD;
                break;

            case WAIT_JOB:  /* End of operation! */
                assert(State->explore.prev != TOS_NODE_ID);
                assert(State->explore.prev != AM_BROADCAST_ADDR);
                del_op(State);
            case WAIT_BUILD:
                break;

            default:
                assert(0);
        }
    }

    event void Prot.done_local (herp_opid_t OpId, error_t E)
    {
        herp_oprec_t Op = call OpTab.internal(OpId);

        assert(Op != NULL);
        prot_done( call OpTab.fetch_user_data(Op) );
    }

    event void Prot.done_remote (am_addr_t Own, herp_opid_t ExtOpId,
                                 error_t E)
    {
        herp_oprec_t Op = call OpTab.external(Own, ExtOpId, TRUE);

        assert(Op != NULL);
        prot_done( call OpTab.fetch_user_data(Op) );
    }

    static error_t update_rtab (route_state_t State,
                                am_addr_t To,
                                am_addr_t NextHop,
                                uint16_t HopsFromDst)
    {
        herp_rthop_t Hop = {
            .first_hop = NextHop,
            .n_hops = HopsFromDst
        };
        herp_opid_t OpId = opid(State);
        herp_rtres_t Res;

        if (State->op.type == EXPLORE && State->explore.job != NULL) {
            Res = call RTab.update_route[OpId](State->explore.job, &Hop);
            State->explore.job = NULL;
        } else {
            Res = call RTab.new_route[OpId](To, &Hop);
        }

        return (Res == HERP_RT_SUBSCRIBED) ? SUCCESS : FAIL;
    }

    static void steal_route (route_state_t State, am_addr_t To)
    {
        herp_rthop_t Hop = {
            .first_hop = To,
            .n_hops = 1
        };

        call RTab.new_route[opid(State)](To, &Hop);
    }

    event void Prot.got_build (const herp_opinfo_t *Info, am_addr_t Prev,
                               uint16_t HopsFromDst)
    {
        herp_oprec_t Op;
        route_state_t State;
        error_t E;

        Op = call OpTab.external(Info->from, Info->ext_opid, FALSE);
        if (Op == NULL) return;     /* Out of memory */

        State = call OpTab.fetch_user_data(Op);

        if (State->op.type == NEW) {
            State->op.type = COLLECT;
            State->op_rec = Op;
        }

        if (Prev != Info->to) {
            steal_route(State, Prev);
        }

        switch (State->op.type) {

            case EXPLORE:
                if (State->op.phase != WAIT_BUILD) return;

                assert(Info->to == State->explore.info.to);
                stop_timer(State);
                State->op.phase = WAIT_ROUTE;
            case COLLECT:
                E = update_rtab(State, Info->to, Prev, HopsFromDst);
                if (E != SUCCESS) {
                    del_op(State);
                }
                break;

            case SEND:      /* Byzantine */
            case PAYLOAD:   /* Byzantine */
            default:
                assert(0);
        }

    }

    static inline error_t fwd_build (explore_state_t *Explore,
                                     const herp_rthop_t *Hop)
    {
        return call Prot.fwd_build(&Explore->info,
                                   Explore->prev,
                                   Hop->n_hops);
    }

    static error_t run_send (route_state_t State, am_addr_t FirstHop)
    {
        return call Prot.send_data(State->send.msg, FirstHop);
    }

    static error_t fwd_payload (route_state_t State, am_addr_t FirstHop)
    {
        return call Prot.fwd_payload(&State->payload.info,
                                     FirstHop,
                                     State->payload.msg,
                                     State->payload.len);
    }

    event void RTab.deliver [herp_opid_t OpId](herp_rtres_t Out, am_addr_t Node,
                                               const herp_rthop_t *Hop)
    {
        herp_oprec_t Op;
        route_state_t State;

        Op = call OpTab.internal(OpId);
        if (Op == NULL) return;

        State = call OpTab.fetch_user_data(Op);

        if (Out != HERP_RT_SUCCESS) {
            if (State->op.type == SEND) {
                retry(State);
            } else {
                del_op(State);
            }
            return;
        }

        switch (State->op.type) {

            case EXPLORE:
                if (State->op.phase != WAIT_ROUTE) {
                    /* This is a stealed route. Some checks, then ignore. */
                    assert(State->explore.info.to != Node);
                    return;
                }
                if (State->explore.info.to != Node) {
                    /* Got the record for a route, subscribed by this
                     * operation, which we are not interested in */
                    return;
                }
                if (State->explore.prev == TOS_NODE_ID) {
                    State->explore.prev = AM_BROADCAST_ADDR;
                    resume_send(State->explore.info.ext_opid);
                    del_op(State);
                } else if (State->explore.prev != AM_BROADCAST_ADDR
                           && fwd_build(&State->explore, Hop) == SUCCESS) {
                    /* If success we wait for protocol confirmation. */
                    State->op.phase = WAIT_JOB;
                } else {
                    del_op(State);
                }
                break;

            case COLLECT:
                del_op(State);
                break;

            case SEND:
                assert(State->op.phase == WAIT_ROUTE);
                if (run_send(State, Hop->first_hop) == SUCCESS) {
                    State->op.phase = WAIT_JOB;
                } else {
                    del_op(State);
                }
                break;

            case PAYLOAD:
                assert(State->op.phase == WAIT_ROUTE);
                if (fwd_payload(State, Hop->first_hop) == SUCCESS) {
                    State->op.phase = WAIT_JOB;
                } else {
                    del_op(State);
                }
                break;

            default:
                assert(0);
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
        if (Info->to == TOS_NODE_ID) {
            void *Payload = call Packet.getPayload(Msg, Len);

            call AMPacket.setDestination(Msg, TOS_NODE_ID);
            call AMPacket.setSource(Msg, Info->from);
            signal Receive.receive(Msg, Payload, Len);

        } else {
            herp_oprec_t Op;
            route_state_t State;
            herp_rtentry_t Entry;

            if (call PayloadPool.empty()) {
                return Msg;
            }

            Op = call OpTab.external(Info->from, Info->ext_opid, FALSE);
            if (Op == NULL) {
                return Msg;
            }

            State = call OpTab.fetch_user_data(Op);
            if (State->op.type != NEW) {
                return Msg;
            }
            State->op_rec = Op;

            State->op.type = PAYLOAD;
            State->op.phase = WAIT_ROUTE;

            if (call RTab.get_route[opid(State)](Info->to, &Entry)
                    != HERP_RT_SUBSCRIBED) {
                del_op(State);
                return Msg;
            }

            State->payload.msg = Msg;
            State->payload.len = Len;
            State->payload.info = *Info;
            Msg = call PayloadPool.get();
        }

        return Msg;
    }

}

