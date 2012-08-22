
 #include <string.h>

 #include <Protocol.h>
 #include <OperationTable.h>
 #include <RoutingP.h>
 #include <Constants.h>

module RoutingP {

    provides {
        interface AMSend;
        interface
    }

    uses {
        interface OperationTable<struct herp_routing> as OpTab;
        interface RoutingTable as RTab[herp_opid_t];
        interface Protocol;
    }

}

implementation {

    static error_t fetch_route (herp_routing_t RoutInfo, herp_opid_t OpId,
                                am_addr_t Target) {

        herp_rtentry_t RT_Entry;
        herp_rtroute_t RT_Route;
        am_addr_t FirstHop;
        error_t RetVal;

        SendTo = AM_BROADCAST_ADDR;
        do switch (call RTab.get_route[OpId](Addr, &RT_Entry)) {

            case HERP_RT_ERROR:
                return FAIL;

            case HERP_RT_VERIFY:
                RT_Route = call RTab.get_job[OpId](RT_Entry);
                if (RT_Route == NULL) {
                    RoutInfo->retry --;
                    break;
                }
                FirstHop = call RTab.get_hop[OpId](RT_Route)->first_hop;
                // TODO: set timeout
                RoutInfo->job = RT_Route;
                RoutInfo->op.phase = EXPLORE_SENDING;
                // TODO: retry-loop
                return call Protocol.send_verify(OpId, Target, FirstHop);

            case HERP_RT_REACH:
                // TODO: set timeout
                RoutInfo->op.phase = EXPLORE_SENDING;
                // TODO: retry-loop
                return call Protocol.send_reach(OpId, Target);

            case HERP_RT_SUBSCRIBED:
                // TODO: set timeout
                RoutInfo->op.phase = WAIT_ROUTE;
                // TODO: retry-loop
                return SUCCESS;

        } while (RoutInfo->retry);

        return FAIL;
    }

    /* --------------------------------------------------------------- */

    event void RTab.deliver [herp_opid_t OpId](herp_rtres_t Outcome, am_addr_t Node, const herp_rthop_t *Hop) {
        herp_oprec_t Op;
        herp_routing_t RoutInfo;

        Op = call OpTab.internal(OpId);
        assert(Op != NULL);

        RoutInfo = call OpTab.fetch_user_data(Op);
        switch (RoutInfo->op.phase) {
            case WAITING_ROUTE:
                RoutInfo->op.phase = EXEC;
                break;
            default:
                assert(0);
        }

        if (RoutInfo->op.type == LOCAL) {
            call Protocol.send_data(
                RoutInfo->data.send.msg,
                RoutInfo->data.send.len
            );
        } else {
            herp_opinfo_t Info = {
                .from       = call OpTab.fetch_owner(Op),
                .to         = RoutInfo->data.route.target,
                .ext_opid   = call OpTab.fetch_external_id(Op)
            };

            call Protocol.fwd_build(
                &Info,
                RoutInfo->data.route.prev,
                RoutInfo->data.route.hops_from_src
            );
        }
    }

    event error_t OpTab.data_init (const herp_oprec_t Op, herp_routing_t Routing) {
        dbg("Out", "Initializing new entry\n");

        Routing->retry = HERP_MAX_RETRY;
        Routing->job = NULL;

        if (call OpTab.fetch_owner(Op) == TOS_NODE_ID) {
            Routing->op.type = LOCAL;
            Routing->data.send.msg = NULL;
            Routing->data.send.len = 0;
        } else {
            Routing->op.type = REMOTE;
            Routing->data.route.prev = AM_BROADCAST_ADDR;
            Routing->data.route.hops_to_src = 0;
            Routing->data.route.target = AM_BROADCAST_ADDR;
        }

        Routing->op.phase = START;

        return SUCCESS;
    }

    event void OpTab.data_dispose (const herp_oprec_t Op, herp_routing_t RoutInfo) {
        if (RoutInfo->job) {
            herp_opid_t OpId;

            /* We have an active job to suppress */
            OpId = call OpTab.fetch_internal_id(Op);
            call RTab.drop_job[OpId](RoutInfo->job);
        }
    }

    command error_t AMSend.send(am_addr_t Addr, message_t *Msg, uint8_t Len) {
        herp_oprec_t Op;
        herp_opid_t OpId;
        herp_routing_t RoutInfo;
        error_t RetVal;

        Op = call OpTab.new_internal();
        if (Op == NULL) return ENOMEM;

        OpId = call OpTab.fetch_internal_id(Op);

        RetVal = call Protocol.init_user_msg(Msg, OpId, Addr)
        if (RetVal != SUCCESS) {
            call OpTab.free_record(Op);
            return FAIL;
        }

        RoutInfo = call OpTab.fetch_user_data(Op);
        assert(RoutInfo->op.type == LOCAL);
        RoutInfo->data.send.msg = Msg;
        RoutInfo->data.send.len = Len;

        RetVal = fetch_route(RoutInfo, OpId, Addr);
        if (RetVal != SUCCESS) {
            call OpTab.free_record(Op);
        }
        return RetVal;
    }

    command error_t AMSend.cancel(message_t *Msg) {
        /* If the user code is good, Msg should contain a decent header,
         * so it carries the useful information for cancelation.
         *
         * This is a low-priority implementation */

        return FAIL;
    }

    event void Protocol.done(herp_opid_t OpId, error_t E) {
        herp_oprec_t Op;
        herp_routing_t RoutInfo;
        bool Close = FALSE;

        Op = call OpTab.internal(OpId);
        assert(Op != NULL);

        RoutInfo = call OpTab.fetch_user_data(Op);
        if (E != SUCCESS) {
            Close = TRUE;
        } else switch (RoutInfo->op.phase) {
            case EXPLORE_SENDING:
                RoutInfo->op.phase = EXPLORE_SENT;
                break;
            case EXEC_TASK:
                Close = TRUE;
                break;
            default:
                assert(0);
        }

        if (Close && RoutInfo->op.type == LOCAL) {
            signal AMSend.sendDone(RoutInfo->data.send.msg, E);
            call OpTab.free_record(Op);
        }
        /* Nothing can be done for closing remote operations... let remote
         * timeout kill it. */
    }

    event messsage_t * Protocol.got_payload (const herp_opinfo_t *Info,
                                             const herp_userdata_t *Data) {
        return Data->msg;
    }

    event void got_explore (const herp_opinfo_t *Info, am_addr_t Prev, uint16_t HopsFromSrc) {
        herp_oprec_t Op;
        herp_routing_t RoutInfo;
        herp_opid_t OpId;

        Op = call OpTab.external(Info->from, Info->ext_opid, FALSE);
        if (Op == NULL) return;

        RoutInfo = call OpTab.fetch_user_data(Op);

        if (RoutInfo->op.type == LOCAL) {
            /* A neighbor is simply propagating our message. */
            return;
        }

        OpId = call OpTab.fetch_internal_id(Op);

        switch (RoutInfo->op.phase) {
            case START:
                RoutInfo->op.phase = EXPORE_PROPAGATE;
                RoutInfo->data.route.prev = Prev;
                RoutInfo->data.route.hops_from_src = HopsFromSrc;
                RoutInfo->data.route.target = Info->to;
                if (fetch_route(RoutInfo, OpId, Info->to) == SUCCESS) {
                    /* Enable timer */
                }
                break;
            case EXPLORE_PROPAGATE:
            case EXPLORE_SENT:
            case WAIT_ROUTE:
                /* Update if prev-hop is better */
                if (Data->hop_count < StoredProto->hop_count) {
                    RoutInfo->data.route.prev = Prev;
                    RoutInfo->data.route.hops_from_src = HopsFromSrc;
                    RoutInfo->data.route.target = Info->to;
                }
            default:
                /* Late, we did it already! */
                break;
        }
    }

    event void got_build (const herp_opinfo_t *Info, am_addr_t Prev, uint16_t HopsFromDst) {
        herp_oprec_t Op;
        herp_routing_t RoutInfo;
        herp_opid_t OpId;
        herp_rthop_t Hop;

        Op = call OpTab.external(Info->from, Info->ext_opid, TRUE);
        if (Op == NULL) return NULL;

        RoutInfo = call OpTab.fetch_user_data(Op);

        /* Phase update */
        switch (RoutInfo->op.phase) {
            case EXPLORE_SENT:
                RoutInfo->op.phase = WAIT_ROUTE;
                break;
            default:
                assert(0);
        }

        OpId = call OpTab.fetch_internal_id(Op);
        Hop.first_hop = Prev,
        Hop.n_hops = HopsFromDst

        if (RoutInfo->job) {
            call RTab.update_route[OpId](RoutInfo->job, &Hop);
            // TODO: check error, retry if needed
        } else {
            call RTab.new_route[OpId](Info->to, &Hop);
            // TODO: check error, retry if needed
        }

    }

    command void * AMSend.getPayload(message_t *Msg) {
        return call Packet.getPayload(Msg, call Packet.maxPayloadLength());
    }

    command uint8_t AMSend.maxPayloadLength() {
        return call Packet.maxPayloadLength();
    }

    command void Packet.clear(message_t *Msg) {
        call SubAMPacket.clear(Msg);
    }

}
