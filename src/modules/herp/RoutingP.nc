
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
        interface OperationTable<struct herp_routing> as OpTab;
        interface RoutingTable as RTab[herp_opid_t];
        interface Protocol;
        interface Packet;
        interface MultiTimer<struct route_state> as Timer;
        interface TimerDelay;
        interface Pool<message_t> as PayloadPool;
    }

}

implementation {

    static error_t fetch_route (herp_opid_t OpId, am_addr_t Target) {

        herp_rtentry_t RT_Entry;
        herp_rtroute_t RT_Route;
        error_t RetVal;

        switch (call RTab.get_route[OpId](Addr, &RT_Entry)) {

            case HERP_RT_ERROR:
                return FAIL;

            case HERP_RT_VERIFY:
                RT_Route = call RTab.get_job[OpId](RT_Entry);
                if (RT_Route == NULL) {
                    return FAIL;
                }
                RouteState->job = RT_Route;
                RouteState->op.phase = EXPLORE_SENDING;
                RetVal = call Protocol.send_verify(
                            OpId,
                            Target,
                            call RTab.get_hop[OpId](RT_Route)->first_hop;
                        );
                if (RetVal != SUCCESS) {
                    call RTab.drop_job[OpId](RT_Route);
                    RouteState->job = NULL;
                }
                return RetVal;

            case HERP_RT_REACH:
                RouteState->op.phase = EXPLORE_SENDING;
                return call Protocol.send_reach(OpId, Target);

            case HERP_RT_SUBSCRIBED:
                RouteState->op.phase = WAIT_ROUTE;
                return SUCCESS;

            default:
                assert(0);
        }
    }

    static inline void close (route_state_t RouteState, error_t E) {
        switch (RouteState->op.type) {
            case SEND:
                call AMSend.sendDone(RouteState->send.msg, E);
                break;
            case PAYLOAD:
                if (RouteState->payload.msg != NULL) {
                    call PayloadPool.put(RouteState->payload.msg);
                }
            default:
                break;
        }
        call OpTab.free_record(RouteState);
    }

    static void restart (route_state_t RouteState) {
        RouteState->op.phase = START;
        // TODO: handle restart. Or let the upper layer handle it?
    }

    /* --------------------------------------------------------------- */

    event void Timer.fired (route_state_t RouteState) {
        assert(RouteState->op.phase == EXPLORE_SENDING);
        if (RouteState->job != NULL) {
            call RTab.drop_route(RouteState->job);
            RouteState->job = NULL;
        }
        close(RouteState, FAIL);
    }

    event void RTab.deliver [herp_opid_t OpId](herp_rtres_t Outcome, am_addr_t Node, const herp_rthop_t *Hop) {
        herp_oprec_t Op;
        route_state_t RouteState;

        Op = call OpTab.internal(OpId);
        assert(Op != NULL);
        RouteState = call OpTab.fetch_user_data(Op);

        assert(RouteState->op.phase == WAIT_ROUTE);

        if (Outcome == HERP_RT_RETRY) {
            restart(RouteState);
        } else {
            error_t E;
            op_type_t OpType = RouteState->op.type;

            if (OpType == SEND) {
                E = call Protocol.send_data(
                        RouteState->send.msg,
                        RouteState->send.data,
                        Hop->first_hop
                    );
            } else {
                if (OpType == ROUTE) {
                    herp_opinfo_t Info = {
                        .from = call OpTab.fetch_owner(Op),
                        .to = RouteState->route.target,
                        .ext_opid = call OpTab.fetch_external_id(Op)
                    };
                    assert(Info.from != TOS_NODE_ID);
                    E = call Protocol.fwd_build(
                            &Info,
                            RouteState->route.prev,
                            Hop->n_hops
                        );
                } else {
                    assert(OpType == PAYLOAD);
                    E = call Protocol.fwd_payload(
                            &RouteState->payload.info
                            Hop->n_hops,
                            RouteState->payload.msg,
                            RouteState->payload.len
                        );
                }
            }

            if (E == SUCCESS) {
                RouteState->op.phase = WAIT_TASK;
            } else {
                close(RouteState, E);
            }
        }
    }

    event error_t OpTab.data_init (const herp_oprec_t Op, route_state_t Routing) {
        /* Note: this sets also correctly the state machine on START
         *       besides setting pointers to NULL.
         */
        memset((void *)Routing, 0, sizeof(struct herp_routing));
        return SUCCESS;
    }

    event void OpTab.data_dispose (const herp_oprec_t Op, route_state_t RouteState) {
        #if 0
        herp_opid_t OpId;

        OpId = call OpTab.fetch_internal_id(Op);
        if (RouteState->job) {    /* We have an active job to suppress */
            call RTab.drop_job[OpId](RouteState->job);
        }
        if (RouteState->sched) {  /* We have an active timer to suppress */
            call ...
        }
        #else
        assert(RouteState->job == NULL);
        assert(RouteState->sched == NULL);
        #endif
    }

    command error_t AMSend.send(am_addr_t Addr, message_t *Msg, uint8_t Len) {
        herp_oprec_t Op;
        herp_opid_t OpId
        error_t RetVal;
        route_state_t RouteState;

        Op = call OpTab.new_internal();
        if (Op == NULL) return ENOMEM;

        RouteState = call OpTab.fetch_user_data(Op);
        RouteState->op.type = SEND;

        OpId = call OpTab.fetch_internal_id(Op);
        RetVal = call Protocol.init_user_msg(Msg, OpId, Addr);
        if (RetVal != SUCCESS) {
            call OpTab.free_record(Op);
            return RetVal;
        }
        RouteState->send.msg = Msg;
        RouteState->send.len = Len;

        // TODO: this is the starting point of FSM for SEND

        RetVal = fetch_route(OpId, Addr);
        if (RetVal != SUCCESS) {
            call OpTab.free_record(Op);
        }
        return RetVal;
    }

    command error_t AMSend.cancel(message_t *Msg) {
        return FAIL;
    }

    event void Protocol.done(herp_opid_t OpId, error_t E) {
        herp_oprec_t Op;
        route_state_t RouteState;

        Op = call OpTab.internal(OpId);
        assert(Op != NULL);
        RouteState = call OpTab.fetch_user_data(Op);

        if (E == SUCCESS) {
            uint32_t T;

            switch (RouteState->op.phase) {

                case EXPLORE_SENDING:
                    if (RouteState->job == NULL) {
                        /* Reach */
                        T = call TimerDelay.for_any_node();
                    } else {
                        /* Verify */
                        uint8_t NHops = call RTab.get_hop[OpId](RT_Route)->n_hops;
                        T = call TimerDelay.for_hops(NHops);
                    }

                    RouteState->sched = call Timer.schedule(T, RouteState);
                    RouteState->EXPLORE_SENT;
                    break;

                case WAIT_TASK:
                    close(RouteState, SUCCESS);
                    break;

                default:
                    assert(0);
            }
        } else {
            close(RouteState, E);
        }
    }

    event message_t * Protocol.got_payload (const herp_opinfo_t *Info, message_t *Msg, uint8_t Len) {

        // TODO: duplicate the message.
        return Msg;
    }

    event void got_explore (const herp_opinfo_t *Info, am_addr_t Prev, uint16_t HopsFromSrc) {
    }

    event void got_build (const herp_opinfo_t *Info, am_addr_t Prev, uint16_t HopsFromDst) {

        herp_oprec_t Op;
        herp_opid_t OpId;
        route_state_t RouteState;
        herp_rthop_t Hop;
        herp_rtres_t Err;

        Op = call OpTab.external(Info->from, Info->ext_opid, TRUE);
        if (Op == NULL) return;
        RouteState = call OpTab.fetch_user_data(Op);
        OpId = call OpTab.fetch_internal_id(Op);

        switch (RouteState->op.phase) {

            case EXPLORE_SENT:
                assert(RouteState->sched != NULL);
                call Timer.nullify(RouteState->sched);
                RouteState->sched = NULL;
                Hop.first_hop = Prev,
                Hop.n_hops = HopsFromDst;
                if (RouteSched->job == NULL) {
                    Err = call RTab.update_route[OpId](RouteSched->job, &Hop);
                } else {
                    Err = call RTab.new_route[OpId](Info->to, &Hop);
                }
                if (Err == HERP_RT_SUBSCRIBED) {
                    RouteState->op.phase = WAIT_ROUTE;
                } else {
                    close(RouteState, FAIL);
                }
                break;

            default:
                /* Assertion is just for hard-checking. After testing
                 * replace with an information drop (could be caused by
                 * byzantine node). */
                assert(0);
        }

    }

    command void * AMSend.getPayload(message_t *Msg) {
        return call Packet.getPayload(Msg, call Packet.payloadLength(Msg));
    }

    command uint8_t AMSend.maxPayloadLength() {
        return call Packet.maxPayloadLength();
    }

}
