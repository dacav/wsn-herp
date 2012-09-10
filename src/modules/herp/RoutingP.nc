
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
        return call Protocol.fwd_explore(
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
        Explore.propagate = (Route == NULL)
                          ? AM_BROADCAST_ADDR
                          : call RTab.get_hop(Route)->first_hop

        if (Explore->info.from == TOS_NODE_ID) {
            /* This is a local operation */
            herp_opid_t OpId = call OpTab.fetch_internal_id(State->op_rec);

            assert(State->info.from == TOS_NODE_ID);
            if (Explore->propagate == AM_BROADCAST_ADDR) {
                E = call Protocol.send_reach(OpId, Explore->info.to);
            } else {
                E = call Protocol.send_verify(OpId, Explore->info.to,
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

    command error_t AMSend.send(am_addr_t Addr, message_t *Msg, uint8_t Len)
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
                State->op.type = EXPLORE;
                State->op_rec = Op;
                set_explore_data(Explore, Prev, HopsFromSrc, Info);
                if (run_explore(State) != SUCCESS) {
                    call OpTab.free_record(Op);
                }
                break;

            case EXPLORE:

                /* Exclude byzantine and useless cases */
                if (State->explore.prev == TOS_NODE_ID) return;
                if (HopsFromSrc >= Expore->hops_from_src) return;

                set_explore_data(Explore, Prev, HopsFromSrc, Info);
                if (State->op.phase != WAIT_ROUTE) {
                    /* Note: don't care if this operation fails */
                    fwd_explore(State);
                }

                break;

            case COLLECT:   /* Byzantine */
            case SEND:      /* Byzantine */
            case PAYLOAD:   /* Byzantine */
            default:
                assert(0);
        }
    }

    event void Prot.done_local (herp_opid_t OpId, error_t E)
    {
    }

    event void Prot.done_remote (am_addr_t Own, herp_opid_t ExtOpId,
                                 error_t E)
    {
    }

    event void Prot.got_build (const herp_opinfo_t *Info, am_addr_t Prev,
                               uint16_t HopsFromDst)
    {
    }

    event void RTab.deliver [herp_opid_t OpId](herp_rtres_t Out, am_addr_t Node,
                                               const herp_rthop_t *Hop)
    {
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

