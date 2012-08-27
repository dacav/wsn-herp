
 #include <string.h>

 #include <Prot.h>
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
        interface Protocol as Prot;
        interface Packet;
        interface MultiTimer<struct route_state> as Timer;
        interface TimerDelay;
        interface Pool<message_t> as PayloadPool;
    }

}

implementation {

    /* -- General purpose operation ---------------------------------- */

    static void end_operation (route_state_t State, error_t E) {

        if (State->op.type == SEND) {
            signal AMSend.sendDone(RouteState->send.msg, E);
        }

        assert(RouteState->send.comm.job == NULL &&
               RouteState->send.comm.sched == NULL);

        call OpTab.free_internal(RouteState->int_opid);
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

        if (Comm.job == NULL) {
            T = call TimerDelay.for_any_node();
        } else {;
            uint8_t NHops = call RTab.get_hop[OpId](Comm->job)->n_hops;
            T = call TimerDelay.for_hops(NHops);
        }

        Comm->sched = call Timer.schedule(T, RouteState);
        RouteState->op.phase = EXPLORE_SENT;
    }

    static void prot_done (route_state_t State) {
        switch (RouteState->op.phase) {

            case EXPLORE_SENDING:
                wait_build(RouteState);
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

        Comm = State.op.type == SEND ? &State->send.comm
             : State.op.type == EXPLORE ? &State->explore.comm
             : NULL;
        assert(Comm != NULL);

        assert(Comm->sched != NULL);
        call Timer.nullify(Comm->sched);
        Comm->sched = NULL;

        if (Comm->job == NULL) {
            E = call RTab.update_route[OpId](Comm->job, &Hop);
            Comm->job = NULL;
        } else {
            E = call RTab.new_route[OpId](Info->to, &Hop);
        }

        if (E == HERP_RT_SUBSCRIBED) {
            State->op.phase = WAIT_ROUTE;
        } else {
            end_operation(State, E);
        }
    }

    /* -- Functions for "SEND" operations ---------------------------- */

    static void send_fetch_route (route_state_t State, am_addr_t Target) {
        herp_rtentry_t RT_Entry;
        herp_rtroute_t RT_Route;
        error_t RetVal;
        herp_opid_t OpId = State->int_opid;

        switch (call RTab.get_route[OpId](Addr, &RT_Entry)) {

            case HERP_RT_ERROR:
                return FAIL;

            case HERP_RT_VERIFY:
                State->op.phase = EXPLORE_SENDING;
                RT_Route = call RTab.get_job[OpId](RT_Entry);
                if (RT_Route == NULL) {
                    return FAIL;
                }
                State->job = RT_Route;
                RetVal = call Prot.send_verify(
                             OpId,
                             Target,
                             call RTab.get_hop[OpId](RT_Route)->first_hop;
                         );
                if (RetVal != SUCCESS) {
                    call RTab.drop_job[OpId](RT_Route);
                    State->job = NULL;
                }
                return RetVal;

            case HERP_RT_REACH:
                State->op.phase = EXPLORE_SENDING;
                return call Prot.send_reach(OpId, Target);

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

        E = call Prot.send_data(RouteState->send.msg, RouteState->send.len,
                                Hop->first_hop);
        if (E == SUCCESS) {
            RouteState->op.phase = EXEC_JOB;
        } else {
            end_operation(State, E);
        }
    }

    /* -- Functions for "EXPLORE" operations ---------------------------- */

    static void explore_start (route_state_t State, const herp_opinfo_t *Info,
                               am_addr_t Prev, uint16_t HopsFromSrc) {
        herp_rtentry_t RT_Entry;
        herp_rtroute_t RT_Route;
        herp_opid_t OpId;
        am_addr_t FwdTo;
        error_t E;

        State->explore.prev = Prev;
        State->explore.hops_from_src = HopsFromSrc;
        State->explore.target = Info->to;

        OpId = State->int_opid;
        FwdTo = AM_BROADCAST_ADDR;
        switch (call RTab.get_route[OpId](Addr, &RT_Entry)) {

            case HERP_RT_ERROR:
                explore_close(State);
                return;

            case HERP_RT_VERIFY:
                RT_Route = call RTab.get_job[OpId](RT_Entry);
                if (RT_Route == NULL) {
                    return FAIL;
                }
                RouteState->explore.job = RT_Route;
                FwdTo = call RTab.get_hop[OpId](RT_Route)->first_hop;
            case HERP_RT_REACH:
                RouteState->op.phase = EXPLORE_SENDING;
                E = call Prot.fwd_explore(&Info, FwdTo, HopsFromSrc);
                break;

            case HERP_RT_SUBSCRIBED:
                RouteState->op.phase = WAIT_ROUTE;
                return;

            default:
                assert(0);
        }

        if (RouteState->expore.job != NULL && E != SUCCESS) {
            call RTab.drop_job[OpId](RT_Route);
            RouteState->explore.job = NULL;
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

        E = call Prot.fwd_build(&Info, RouteState->route.prev, Hop->n_hops);
        end_operation(State, E);
    }

    /* -- Functions for PAYLOAD operations -------------------------- */

    static void payload_rtab_deliver (route_state_t State, herp_oprec_t *Hop) {
        error_t E;

        E = call Prot.fwd_payload(&RouteState->payload.info Hop->n_hops,
                                  RouteState->payload.msg,
                                  RouteState->payload.len);
        close(State, E);
    }

    /* -- Checked stuff ---------------------------------------------- */

    event error_t OpTab.data_init (const herp_oprec_t Op, route_state_t Routing) {
        /* Note: this sets also correctly the state machine on START
         *       besides setting pointers to NULL.
         */
        memset((void *)Routing, 0, sizeof(struct herp_routing));
        Routing->int_opid = call OpTab.fetch_internal_id(Op);
        return SUCCESS;
    }

    event void OpTab.data_dispose (const herp_oprec_t Op, route_state_t RouteState) {
        assert(RouteState->job == NULL);
        assert(RouteState->sched == NULL);
    }

    command error_t AMSend.send(am_addr_t Addr, message_t *Msg, uint8_t Len) {
        herp_oprec_t Op;
        herp_opid_t OpId
        error_t RetVal;
        route_state_t RouteState;

        Op = call OpTab.new_internal();
        if (Op == NULL) return ENOMEM;

        RouteState = call OpTab.fetch_user_data(Op);
        assert(RouteState->op.phase == START);
        RouteState->op.type = SEND;

        OpId = call OpTab.fetch_internal_id(Op);
        RetVal = call Prot.init_user_msg(Msg, OpId, Addr);
        if (RetVal != SUCCESS) {
            call OpTab.free_record(Op);
            return RetVal;
        }
        RouteState->send.msg = Msg;
        RouteState->send.len = Len;

        RetVal = send_fetch_route(RouteState, Addr);
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
                assert(State->op.phase == START);
                State->op.type = EXPLORE;
                explore_start(State, Info, Prev, HopsFromSrc);
                break;

            case EXPLORE:
                explore_back_cand(State, Prev, HopsFromSrc);
                break;

            default:
                assert(0);  // TODO: change. Mind Byzantine.
        }

    }

    event void Prot.done(herp_opid_t OpId, error_t E) {
        herp_oprec_t Op;
        route_state_t State

        Op = call OpTab.internal(OpId);
        assert(Op != NULL);
        State = call OpTab.fetch_user_data(Op);
        assert(State->op.type != NEW);

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
            default:
                assert(0);
        }

    }

    event void Prot.got_build (const herp_opinfo_t *Info, am_addr_t Prev, uint16_t HopsFromDst) {
        herp_oprec_t Op;
        route_state_t State;

        Op = call OpTab.external(Info->from, Info->ext_opid, TRUE);
        if (Op == NULL) return;
        State = call OpTab.fetch_user_data(Op);

        assert(State->op.type != NEW);  // by construction

        if (State->op.type != PAYLOAD) {
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
            end_operation(State, ERETRY);
            // TODO: fix this: retry automatically
            // (note: it may be OK in SEND, but for EXPLORE and PAYLOAD
            // This is a real crap!
        } else switch (State->op.type) {

            case SEND:
                send_rtab_deliver(State, Hop);
                break;

            case EXPLORE:
                Info.from = call OpTab.fetch_owner(Op);
                assert(Node == State->route.target);
                Info.to = Node;
                Info.ext_opid = call OpTab.fetch_external_id(Op);
                explore_rtab_deliver(State, &Info, Node, Hop);
                break;

            case PAYLOAD:
                payload_rtab_deliver(State, Hop) {
                break;

            default:
                assert(0);
        }

    }

    command void * AMSend.getPayload(message_t *Msg) {
        return call Packet.getPayload(Msg, call Packet.payloadLength(Msg));
    }

    command uint8_t AMSend.maxPayloadLength() {
        return call Packet.maxPayloadLength();
    }

    command error_t AMSend.cancel(message_t *Msg) {
        return FAIL;
    }

    event message_t * Prot.got_payload (const herp_opinfo_t *Info, message_t *Msg, uint8_t Len) {



        return Msg;
    }



}

