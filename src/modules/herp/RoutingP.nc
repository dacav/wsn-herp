
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
        interface TimerDelay;
        interface MultiTimer<struct route_state> as Timer;
        interface Pool<message_t> as PayloadPool;
    }

}

implementation {

    /* -- General purpose operation ---------------------------------- */

    static void end_operation (route_state_t State, error_t E);
    static void wait_build (route_state_t State);
    static void prot_done (route_state_t State);
    static void prot_got_build (route_state_t State, const herp_opinfo_t *Info,
                                am_addr_t Prev, uint8_t HopsFromDst);
    static void restart (route_state_t State);
    static message_t * msg_dup (message_t *Src);
    static void prot_done_demux (herp_oprec_t Op, error_t E);

    /* -- Functions for "SEND" operations ---------------------------- */

    static error_t send_fetch_route (route_state_t State);
    static void send_rtab_deliver (route_state_t State, const herp_rthop_t *Hop);

    /* -- Functions for "EXPLORE" operations -------------------------- */

    static void explore_fetch_route (route_state_t State, uint16_t HopsFromSrc);
    static void explore_start (route_state_t State, const herp_opinfo_t *Info,
                               am_addr_t Prev, uint16_t HopsFromSrc);
    static void explore_back_cand(route_state_t State, am_addr_t Prev, uint16_t HopsFromSrc);
    static void explore_rtab_deliver (route_state_t State, const herp_opinfo_t *Info,
                                      const herp_rthop_t *Hop);

    /* -- Functions for PAYLOAD operations ---------------------------- */

    static void payload_rtab_deliver (route_state_t State, const herp_rthop_t *Hop);
    static void payload_fetch_route (route_state_t State);

    /* -- Commands, events and stuff ---------------------------------- */

    event error_t OpTab.data_init (const herp_oprec_t Op, route_state_t Routing) {
        /* Note: this sets also correctly the state machine on START
         *       besides setting pointers to NULL.
         */
        memset((void *)Routing, 0, sizeof(struct route_state));
        Routing->restart = HERP_MAX_RETRY;
        Routing->int_opid = call OpTab.fetch_internal_id(Op);
        return SUCCESS;
    }

    event void OpTab.data_dispose (const herp_oprec_t Op, route_state_t State) {
        comm_state_t Comm;

        Comm = State->op.type == SEND ? &State->send.comm
             : State->op.type == EXPLORE ? &State->explore.comm
             : NULL;

        if (Comm) {
            assert(Comm->job == NULL);
            assert(Comm->sched == NULL);
        }
    }

    command error_t AMSend.send(am_addr_t Addr, message_t *Msg, uint8_t Len) {
        herp_oprec_t Op;
        herp_opid_t OpId;
        error_t RetVal;
        route_state_t State;

        Op = call OpTab.new_internal();
        if (Op == NULL) return ENOMEM;

        State = call OpTab.fetch_user_data(Op);
        assert(State->op.phase == START);
        State->op.type = SEND;

        OpId = call OpTab.fetch_internal_id(Op);
        RetVal = call Prot.init_user_msg(Msg, OpId, Addr);
        if (RetVal != SUCCESS) {
            call OpTab.free_record(Op);
            return RetVal;
        }
        State->send.target = Addr;
        State->send.msg = Msg;
        State->send.len = Len;

        RetVal = send_fetch_route(State);
        if (RetVal != SUCCESS) {
            call OpTab.free_record(Op);
        }
        return RetVal;
    }

    event void Timer.fired (route_state_t State) {
        switch (State->op.type) {
            case SEND:
                State->send.comm.sched = NULL;
                break;
            case EXPLORE:
                State->explore.comm.sched = NULL;
                break;

            case NEW:
            case PAYLOAD:
            default:
                assert(0);
        }

        end_operation(State, FAIL);
    }

    event void Prot.got_explore (const herp_opinfo_t *Info, am_addr_t Prev,
                                 uint16_t HopsFromSrc) {
        herp_oprec_t Op;
        route_state_t State;

        Op = call OpTab.external(Info->from, Info->ext_opid, FALSE);
        if (Op == NULL) return;
        State = call OpTab.fetch_user_data(Op);

        switch (State->op.type) {

            case NEW:
                /* New explore operation required */
                assert(State->op.phase == START);
                explore_start(State, Info, Prev, HopsFromSrc);
                break;

            case EXPLORE:
                /* Consider other explore messages having better path */
                explore_back_cand(State, Prev, HopsFromSrc);
                break;

            case SEND:
                /* Ignore explore messages sent by neighbors for us */
                break;

            default:
                assert(0);  // TODO: change. Mind Byzantine.
        }

    }

    event void Prot.done_local (herp_opid_t OpId, error_t E) {
        prot_done_demux(call OpTab.internal(OpId), E);
    }

    event void Prot.done_remote (am_addr_t Own, herp_opid_t ExtOpId, error_t E) {
        herp_oprec_t Op = call OpTab.external(Own, ExtOpId, TRUE);

        if (Op != NULL) {
            prot_done_demux(Op, E);
        }
    }

    event void Prot.got_build (const herp_opinfo_t *Info, am_addr_t Prev, uint16_t HopsFromDst) {
        herp_oprec_t Op;
        route_state_t State;

        Op = call OpTab.external(Info->from, Info->ext_opid, TRUE);
        if (Op == NULL) {
            Op = call OpTab.new_internal();
        }
        State = call OpTab.fetch_user_data(Op);

        switch (State->op.type) {

            case PAYLOAD:
                /* TODO: PAYLOAD may come from byzantine, don't assert! */
                assert(0);
                break;

            case NEW:
                State->op.type = COLLECT;
            default:
                prot_got_build(State, Info, Prev, HopsFromDst);
        }
    }

    event void RTab.deliver [herp_opid_t OpId](herp_rtres_t Out, am_addr_t Node, const herp_rthop_t *Hop) {
        herp_oprec_t Op;
        route_state_t State;
        herp_opinfo_t Info;

        Op = call OpTab.internal(OpId);
        assert(Op != NULL);
        State = call OpTab.fetch_user_data(Op);

        if (Out == HERP_RT_RETRY) {
            restart(State);
        } else switch (State->op.type) {

            case SEND:
                send_rtab_deliver(State, Hop);
                break;

            case EXPLORE:
                Info.from = call OpTab.fetch_owner(Op);
                assert(Node == State->explore.info.to);
                Info.to = Node;
                Info.ext_opid = call OpTab.fetch_external_id(Op);
                explore_rtab_deliver(State, &Info, Hop);
                break;

            case COLLECT:
                end_operation(State, SUCCESS);
                break;

            case PAYLOAD:
                payload_rtab_deliver(State, Hop);
                break;

            default:
                assert(0);
        }

    }

    command void * AMSend.getPayload(message_t *Msg, uint8_t Len) {
        return call Packet.getPayload(Msg, Len);
    }

    command uint8_t AMSend.maxPayloadLength() {
        return call Packet.maxPayloadLength();
    }

    command error_t AMSend.cancel(message_t *Msg) {
        return FAIL;
    }

    event message_t * Prot.got_payload (const herp_opinfo_t *Info, message_t *Msg, uint8_t Len) {
        if (Info->to == TOS_NODE_ID) {
            void * Payload = call Packet.getPayload(Msg, Len);
            signal Receive.receive(Msg, Payload, Len);
        } else if (!call PayloadPool.empty()) {
            herp_oprec_t Op;

            Op = call OpTab.external(Info->from, Info->ext_opid, FALSE);
            if (Op != NULL) {
                message_t *MsgCopy;
                route_state_t State;

                State = call OpTab.fetch_user_data(Op);
                // avoid messing with other operations:
                if (State->op.type != NEW) return Msg;

                MsgCopy = msg_dup(Msg);
                if (MsgCopy == NULL) {
                    end_operation(State, ENOMEM);
                } else {
                    State->op.type = PAYLOAD;
                    State->payload.msg = MsgCopy;
                    State->payload.len = Len;
                    State->payload.info = *Info;

                    payload_fetch_route(State);
                }
            }
        }

        return Msg;
    }

    /* -- General purpose operation ---------------------------------- */

    static void end_operation (route_state_t State, error_t E) {

        if (State->op.type == SEND) {
            signal AMSend.sendDone(State->send.msg, E);
        } else if (State->op.type == PAYLOAD) {
            message_t *Msg = State->payload.msg;
            if (Msg != NULL) {
                call PayloadPool.put(Msg);
            }
        }
        call OpTab.free_internal(State->int_opid);
    }

    static void wait_build (route_state_t State) {
        herp_opid_t OpId = State->int_opid;
        comm_state_t Comm;
        uint32_t T;

        Comm = State->op.type == SEND ? &State->send.comm
             : State->op.type == EXPLORE ? &State->explore.comm
             : NULL;
        assert(Comm != NULL);
        assert(Comm->sched == NULL);

        if (Comm->job == NULL) {
            T = call TimerDelay.for_any_node();
        } else {
            uint8_t NHops = (call RTab.get_hop[OpId](Comm->job))->n_hops;
            T = call TimerDelay.for_hops(NHops);
        }

        Comm->sched = call Timer.schedule(T, State);
        assert(Comm->sched != NULL);
    }

    static void prot_done (route_state_t State) {
        if (State->op.type == EXPLORE && State->explore.info.to == TOS_NODE_ID) {
            end_operation(State, SUCCESS);
        } else switch (State->op.phase) {

            case EXPLORE_SENDING:
                State->op.phase = EXPLORE_SENT;
                wait_build(State);
                break;

            case EXEC_JOB:
                end_operation(State, SUCCESS);
                break;

            default:
                assert(0);
        }
    }

    static void prot_got_build (route_state_t State, const herp_opinfo_t *Info, am_addr_t Prev, uint8_t HopsFromDst) {
        herp_rthop_t Hop = {
            .first_hop = Prev,
            .n_hops = HopsFromDst
        };
        herp_opid_t OpId = State->int_opid;
        herp_rtres_t E;
        comm_state_t Comm;

        Comm = State->op.type == SEND ? &State->send.comm
             : State->op.type == EXPLORE ? &State->explore.comm
             : NULL;

        if (Comm) {
            assert(State->op.phase == EXPLORE_SENT);

            assert(Comm->sched != NULL);
            call Timer.nullify(Comm->sched);
            Comm->sched = NULL;

            if (Comm->job != NULL) {
                E = call RTab.update_route[OpId](Comm->job, &Hop);
                Comm->job = NULL;
            } else {
                E = call RTab.new_route[OpId](Info->to, &Hop);
            }
        } else {
            E = call RTab.new_route[OpId](Info->to, &Hop);
        }

        if (E == HERP_RT_SUBSCRIBED) {
            State->op.phase = WAIT_ROUTE;
        } else {
            end_operation(State, E);
        }
    }

    static void restart (route_state_t State) {
        if (State->restart == 0) {
            end_operation(State, FAIL);
        }
        State->restart --;

        State->op.phase = START;
        switch (State->op.type) {

            case SEND:
                if (send_fetch_route(State) != SUCCESS) {
                    end_operation(State, FAIL);
                }
                break;

            case EXPLORE:
                break;

            case PAYLOAD:
                payload_fetch_route(State);
                break;

            case NEW:
            default:
                assert(0);
        }

    }

    static void prot_done_demux (herp_oprec_t Op, error_t E) {
        route_state_t State;

        assert(Op != NULL);
        State = call OpTab.fetch_user_data(Op);

        switch (State->op.type) {

            case SEND:
            case EXPLORE:
                if (E == SUCCESS) {
                    prot_done(State);
                } else {
                    end_operation(State, E);
                }
                break;

            case PAYLOAD:
                break;

            case NEW:
            default:
                assert(0);
        }
    }

    /* -- Functions for "SEND" operations ---------------------------- */

    static error_t send_fetch_route (route_state_t State) {
        herp_rtentry_t RT_Entry;
        herp_rtroute_t RT_Route;
        error_t RetVal;
        herp_opid_t OpId = State->int_opid;

        switch (call RTab.get_route[OpId](State->send.target,
                                          &RT_Entry)) {

            case HERP_RT_ERROR:
                return FAIL;

            case HERP_RT_VERIFY:
                State->op.phase = EXPLORE_SENDING;
                RT_Route = call RTab.get_job[OpId](RT_Entry);
                if (RT_Route == NULL) {
                    return FAIL;
                }
                State->send.comm.job = RT_Route;
                RetVal = call Prot.send_verify(
                             OpId,
                             State->send.target,
                             (call RTab.get_hop[OpId](RT_Route))->first_hop
                         );
                if (RetVal != SUCCESS) {
                    call RTab.drop_job[OpId](RT_Route);
                    State->send.comm.job = NULL;
                }
                return RetVal;

            case HERP_RT_REACH:
                State->op.phase = EXPLORE_SENDING;
                return call Prot.send_reach(OpId, State->send.target);

            case HERP_RT_SUBSCRIBED:
                State->op.phase = WAIT_ROUTE;
                return SUCCESS;

            default:
                assert(0);
        }
    }

    static void send_rtab_deliver (route_state_t State, const herp_rthop_t *Hop) {
        error_t E;
        assert(State->op.phase == WAIT_ROUTE);

        E = call Prot.send_data(State->send.msg, State->send.len,
                                Hop->first_hop);
        if (E == SUCCESS) {
            State->op.phase = EXEC_JOB;
        } else {
            end_operation(State, E);
        }
    }

    /* -- Functions for "EXPLORE" operations -------------------------- */

    static void explore_fetch_route (route_state_t State, uint16_t HopsFromSrc) {
        herp_opid_t OpId;
        am_addr_t FwdTo;
        herp_rtentry_t RT_Entry;
        herp_rtroute_t RT_Route;
        error_t E;

        OpId = State->int_opid;
        FwdTo = AM_BROADCAST_ADDR;
        RT_Route = NULL;
        switch (call RTab.get_route[OpId](State->explore.info.to,
                                          &RT_Entry)) {

            case HERP_RT_ERROR:
                end_operation(State, FAIL);
                return;

            case HERP_RT_VERIFY:
                RT_Route = call RTab.get_job[OpId](RT_Entry);
                if (RT_Route == NULL) {
                    end_operation(State, FAIL);
                }
                State->explore.comm.job = RT_Route;
                FwdTo = (call RTab.get_hop[OpId](RT_Route))->first_hop;
            case HERP_RT_REACH:
                State->op.phase = EXPLORE_SENDING;
                E = call Prot.fwd_explore(&State->explore.info, FwdTo,
                                          HopsFromSrc);
                break;

            case HERP_RT_SUBSCRIBED:
                State->op.phase = WAIT_ROUTE;
                return;

            default:
                assert(0);
        }

        if (E != SUCCESS) {
            if (RT_Route != NULL) {
                call RTab.drop_job[OpId](RT_Route);
                State->explore.comm.job = NULL;
            }
            end_operation(State, FAIL);
        }
    }

    static void explore_start (route_state_t State, const herp_opinfo_t *Info,
                               am_addr_t Prev, uint16_t HopsFromSrc) {
        State->op.type = EXPLORE;
        State->explore.prev = Prev;
        State->explore.hops_from_src = HopsFromSrc;
        State->explore.info = *Info;

        if (Info->to == TOS_NODE_ID) {
            call Prot.send_build(State->int_opid, Info, Prev);
        } else {
            explore_fetch_route(State, HopsFromSrc);
        }
    }

    static void explore_back_cand(route_state_t State, am_addr_t Prev, uint16_t HopsFromSrc) {
        if (HopsFromSrc < State->explore.hops_from_src) {
            State->explore.prev = Prev;
            State->explore.hops_from_src = HopsFromSrc;
        }
    }

    static void explore_rtab_deliver (route_state_t State, const herp_opinfo_t *Info, const herp_rthop_t *Hop) {
        error_t E;

        assert(State->op.phase == WAIT_ROUTE);

        E = call Prot.fwd_build(Info, State->explore.prev, Hop->n_hops);
        end_operation(State, E);
    }

    /* -- Functions for PAYLOAD operations --------------------------- */

    static message_t * msg_dup (message_t *Src) {
        message_t *Ret;

        Ret = call PayloadPool.get();
        if (Ret != NULL) {
            memcpy((void *)Ret, (const void *)Src, sizeof(message_t));
        }
        return Ret;
    }

    static void payload_rtab_deliver (route_state_t State, const herp_rthop_t *Hop) {
        error_t E;

        assert(State->op.phase == WAIT_ROUTE);
        E = call Prot.fwd_payload(&State->payload.info, Hop->first_hop,
                                  State->payload.msg, State->payload.len);
        end_operation(State, E);
    }


    static void payload_fetch_route (route_state_t State) {

        herp_rtentry_t RT_Entry;
        am_addr_t To = State->payload.info.to;

        switch (call RTab.get_route[State->int_opid](To, &RT_Entry)) {

            case HERP_RT_ERROR:
            case HERP_RT_VERIFY:
            case HERP_RT_REACH:
                end_operation(State, FAIL);
                break;

            case HERP_RT_SUBSCRIBED:
                State->op.phase = WAIT_ROUTE;
                break;

            default:
                assert(0);

        }
    }

}

