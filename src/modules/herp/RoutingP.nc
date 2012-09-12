
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
        interface Queue<route_state_t> RetryQueue;
    }

}

implementation {

    event error_t OpTab.data_init (route_state_t Routing)
    {
        memset((void *)Routing, 0, sizeof(struct route_state));
        return SUCCESS;
    }

    event void OpTab.data_dispose (route_state_t State)
    {
        switch (State->op.type) {

            case EXPLORE:
                if (State->explore.job) {
                    call RTab.drop_job(State->explore.job);
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

        Op = call OpTab.new_internal();
        if (Op == NULL) return NULL;

        State = call OpTab.fetch_user_data(Op);
        assert(State->op.type == NEW &&
               State->op.phase == START);
        State->op_rec = Op;

        return State;
    }

    static inline error_t fwd_explore (route_state_t State)
    {
        return call Prot.fwd_explore(
                    &State->explore.info,
                    State->explore.first_hop,
                    State->explore.hops_from_src
               );
    }

    static void run_explore (route_state_t State)
    {
        herp_rtentry_t Entry;
        herp_rtroute_t Route = NULL;
        explore_state_t *Explore;
        error_t E;

        switch (call RTab.get_route(State->send.target, &Entry)) {
            case HERP_RT_ERROR:
                return ENOMEM;

            case HERP_RT_SUBSCRIBED:
                /* Waiting the next-hop. */
                State->op.phase = WAIT_ROUTE;
                return SUCCESS;

            case HERP_RT_VERIFY:
                Route = call RTab.get_job(Entry);
                if (Route == NULL) return ERETRY;
            case HERP_RT_REACH:
                break;

            default:
                assert(0)
        };

        State->op.phase = WAIT_PROT;
        Explore = &State->explore;
        Explore->job = Route;
        Explore->propagate = (Route == NULL)
                           ? AM_BROADCAST_ADDR
                           : call RTab.get_hop(Route)->first_hop

        if (Explore->info.from == TOS_NODE_ID) {
            /* This is a local operation */
            herp_opid_t OpId = call OpTab.fetch_internal_id(State->op_rec);

            assert(State->info.from == TOS_NODE_ID);
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

    static error_t new_explore (am_addr_t Target)
    {
        route_state_t State;
        error_t Ret;

        State = new_op();
        if (State == NULL) return ENOMEM;

        State->op.type = EXPLORE;
        State->explore.prev = TOS_NODE_ID;

        opinfo_init(&State->info,
                    call OpTab.fetch_external_id(State->op_rec),
                    TOS_NODE_ID,
                    Target);

        Ret = run_explore(State);
        if (Ret != SUCCESS) {
            call OpTab.free_record(State->op_rec);
        }
        return Ret;
    }

    task void send_retry_task ()
    {
        route_state_t State;
        error_t E;

        assert(call RetryQueue.empty() == FALSE);
        State = call RetryQueue.dequeue();

        E = send_fetch_route(State);
        if (E != SUCCESS) {
            call AMSend.sendDone(State->send.msg, E);
            call OpTab.free_record(State->op_rec);
        }
    }

    static error_t retry (route_state_t State)
    {
        error_t Ret;

        if (State->send.retry == 0) return FAIL;

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
        error_t Ret;

        switch (call RTab.get_route(State->send.target, &Entry)) {
            case HERP_RT_ERROR:
                return ENOMEM;

            case HERP_RT_SUBSCRIBED:
                /* Waiting the next-hop. */
                State->op.phase = WAIT_ROUTE;
                return SUCCESS;

            case HERP_RT_VERIFY:
            case HERP_RT_REACH:
                /* Start a reach operation and retry later. */
                Ret = new_explore(State->send.target);
                if (Ret == SUCCESS) return retry(State);
                return Ret;

            default:
                assert(0)

        };
    }

    command error_t AMSend.send (am_addr_t Addr, message_t *Msg, uint8_t Len)
    {
        error_t RetVal;
        route_state_t State;

        State = new_op();
        if (Op == NULL) return ENOMEM;

        State = call OpTab.fetch_user_data(Op);
        assert(State->op.type == NEW &&
               State->op.phase == START);

        /* -- Initialization ------------------------------------------ */

        State->op.type = SEND;

        RetVal = call Prot.init_user_msg(Msg, OpId, Addr);
        if (RetVal != SUCCESS) {
            call OpTab.free_record(Op);
            return RetVal;
        }

        call Packet.setPayloadLength(Msg, Len);

        State->send.msg = Msg;
        State->send.target = Addr;
        State->send.retry = HERP_MAX_RETRY + 1;

        /* -- Start the send process ---------------------------------- */

        RetVal = send_fetch_route(State);
        if (RetVal != SUCCESS) {
            call OpTab.free_record(Op);
        }
        return RetVal;
    }

    event void Timer.fired (route_state_t State)
    {
        assert(State->op.type == EXPLORE);
        assert(State->explore.sched != NULL);

        State->explore.sched = NULL;
        if (State->explore.job != NULL) {
            call RTab.drop_route(State->explore.job);
            State->explore.job = NULL;
        }
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

    static void start_timer (explore_state_t *Explore)
    {
        uint32_t T;

        if (Explore->job == NULL) {
            T = call TimerDelay.for_any_node();
        } else {
            T = call TimerDelay.for_hops(
                    call RTab.get_hop(Explore->job)->n_hops;
                );
        }

        Explore->sched = call Timer.schedule(T);
    }

    static void stop_timer (explore_state_t *Explore)
    {
        if (Explore->sched == NULL) return;
        call Timer.nullify(Explore->sched);
        Explore->sched = NULL;
    }

    static void restart_timer (explore_state_t *Explore)
    {
        stop_timer(Explore);
        start_timer(Explore);
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
                    E = call Prot.send_build(
                            call OpTab.fetch_internal_id(Op),
                            Info,
                            Prev
                        );
                } else {
                    State->op.type = EXPLORE;
                    set_explore_data(Explore, Prev, HopsFromSrc, Info);
                    E = run_explore(State);
                }
                if (E != SUCCESS) {
                    call OpTab.free_record(Op);
                }
                break;

            case EXPLORE:

                /* Exclude byzantine and useless cases */
                if (State->explore.prev == TOS_NODE_ID) return;
                if (HopsFromSrc >= Expore->hops_from_src) return;

                set_explore_data(Explore, Prev, HopsFromSrc, Info);
                if (State->op.phase != WAIT_ROUTE) {
                    if (fwd_explore(State) == SUCCESS) {
                        restart_timer(Explore);
                    }
                }

                break;

            case COLLECT:   /* Byzantine */
            case SEND:      /* Byzantine */
            case PAYLOAD:   /* Byzantine */
            default:
                assert(0);
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
                signal AMSend.sendDone(State->msg, SUCCESS);
            case PAYLOAD:
            case COLLECT:
                assert(State->op.phase == WAIT_JOB);
                call OpTab.free_record(State->op_rec);
                return;

            default:
                assert(0);
        }

        Explore = &State->explore;
        switch (State->op.phase) {

            case WAIT_PROT:
                enable_timer(Explore);
                State->op.phase = WAIT_BUILD;
                break;

            case WAIT_JOB:  /* End of operation! */
                call OpTab.free_record(State->op_rec);
                break;

            case WAIT_BUILD:
                break;

            default:
                assert(0);
        }
    }

    event void Prot.done_local (herp_opid_t OpId, error_t E)
    {
        herp_opid_t Op = call OpTab.internal(OpId);

        assert(Op != NULL);
        prot_done( call OpTab.fetch_user_data(Op) );
    }

    event void Prot.done_remote (am_addr_t Own, herp_opid_t ExtOpId,
                                 error_t E)
    {
        herp_opid_t Op = call OpTab.external(Own, ExtOpId, TRUE);

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
        herp_opid_t OpId = call OpTab.fetch_internal_id(State->op_rec);
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
        herp_opid_t OpId = call OpTab.fetch_internal_id(State->op_rec);
        herp_rthop_t Hop = {
            .first_hop = To,
            .n_hops = 1
        };

        call RTab.new_route[OpId](To, Hop);
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
        }

        if (Prev != Info->to) {
            steal_route(State, Prev);
        }

        switch (State->op.type) {

            case EXPLORE:
                // TODO: change assertions in "byzantine" after testing.
                assert(State->op.phase == WAIT_BUILD);
                assert(Info->to == State->explore.info.to);

                stop_timer(&State->explore);
                State->op.phase = WAIT_ROUTE;
            case COLLECT:
                E = update_rtab(State, Info->to, Prev, HopsFromDst);
                if (E != SUCCESS) {
                    call OpTab.free_record(State->op_rec);
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
        uint8_t MsgLen = call Packet.payloadLength(State->send.msg);
        return call Prot.send_data(State->send.msg, MsgLen, FirstHop);
    }

    static error_t fwd_payload (route_state_t State, am_addr_t FirstHop)
    {
        return call Prot.fwd_payload(&State->info, FirstHop, State->msg,
                                     State->len);
    }

    event void RTab.deliver [herp_opid_t OpId](herp_rtres_t Out, am_addr_t Node,
                                               const herp_rthop_t *Hop)
    {
        herp_oprec_t Op = call OpTab.internal(OpId);
        route_state_t State;

        assert(Op != NULL);
        State = call OpTab.fetch_user_data(Op);

        if (Out != HERP_RT_SUCCESS) {
            if (State->op.type == SEND) {
                retry(State);
            } else {
                call OpTab.free_record(State->op_rec);
            }
            return;
        }

        switch (State->op.type) {

            case EXPLORE:
                if (State->op.phase != WAIT_ROUTE) {
                    /* This is a stealed route. Some checks, then ignore. */
                    assert(State->op.phase == WAIT_BUILD);
                    assert(State->explore.info.to != Node);
                    return;
                }
                if (State->explore.info.to != Node) {
                    /* Got the record for a route, subscribed by this
                     * operation, which we are not interested in */

                    assert(0);  // Does this really happen at this point?
                    return;
                }
                if (State->explore.prev != TOS_NODE_ID) {
                    if (fwd_build(&State->explore, Hop) == SUCCESS) {
                        /* If success we wait for protocol confirmation. */
                        State->op.phase = WAIT_JOB;
                    } else {
                        /* Else we terminate the operation right now */
                        call OpTab.free_record(State->op_rec);
                    }
                }
                break;

            case COLLECT:
                call OpTab.free_record(State->op_rec);
                break;

            case SEND:
                assert(State->op.phase == WAIT_ROUTE);
                if (run_send(State, Hop->first_hop) == SUCCESS) {
                    State->op.phase = WAIT_JOB;
                } else {
                    call OpTab.free_record(State->op_rec);
                }
                break;

            case PAYLOAD:
                assert(State->op.phase == WAIT_ROUTE);
                if (fwd_payload(State, Next) == SUCCESS) {
                    State->op.phase = WAIT_JOB;
                } else {
                    call OpTab.free_record(State->op_rec);
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
            call Recieve.receive(Msg, Payload, Len);

        } else {
            herp_oprec_t Op;
            route_state_t State;
            herp_rtentry_t Entry;
       
            if (!call PayloadPool.empty()) {
                return Msg;
            }

            Op = call OpTab.external(Info->from, Info->ext_opid, FALSE);
            if (Op == NULL) {
                return Msg;
            }

            State = call OpTab.fetch_user_data(Op);
            if (State->op.type != NEW) {
                call OpTab.free_record(Op);
                return Msg;
            }

            State->op.type = PAYLOAD;
            State->op.phase = WAIT_ROUTE;

            if (call RTab.get_route(Info->to, &Entry) != HERP_RT_SUBSCRIBED) {
                call OpTab.free_record(Op);
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

