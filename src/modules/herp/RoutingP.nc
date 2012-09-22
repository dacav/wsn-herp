
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
    }

    static inline herp_opid_t opid (route_state_t State)
    {
        return call OpTab.fetch_internal_id(State->op.rec);
    }

    static inline void del_op (route_state_t State)
    {
        call OpTab.free_record(State->op.rec);
    }

    static inline route_state_t new_op ()
    {
        herp_oprec_t Op = call OpTab.new_internal();
        if (Op == NULL) return NULL;
        return call OpTab.fetch_user_data(Op);
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
                    State->op.phase = WAIT_PROT;
                }
                break;

            case NEW:
            default:
                assert(FALSE);
        }

        return E;
    }

    static error_t start_explore (am_addr_t Target)
    {
        return FAIL;
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
            signal AMSend.sendDone(State->send.msg, E);
            del_op(State);
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
                E = start_explore(Addr);
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

        E = call Prot.init_user_msg(Msg, opid(State), Addr);
        if (E != SUCCESS) {
            del_op(State);
            return E;
        }

        State->send.msg = Msg;
        State->send.to = Addr;
        State->send.retry = HERP_MAX_RETRY;

        E = start_send(State);
        if (E != SUCCESS) {
            del_op(State);
        }
        return E;
    }

    static void prot_done (route_state_t State, error_t E)
    {
        switch (State->op.type) {
            case SEND:
                assert(State->op.phase == WAIT_PROT);
                signal AMSend.sendDone(State->send.msg, E);
                del_op(State);

            default:
                assert(FALSE);
        }
    }

    event void Prot.done_local (herp_opid_t OpId, error_t E)
    {
        herp_oprec_t Op = call OpTab.internal(OpId);

        assert(Op != NULL);
        prot_done(call OpTab.fetch_user_data(Op), E);
    }

    event void Prot.done_remote (am_addr_t Own, herp_opid_t ExtOpId,
                                 error_t E)
    {
        herp_oprec_t Op = call OpTab.external(Own, ExtOpId, TRUE);

        assert(Op != NULL);
        prot_done(call OpTab.fetch_user_data(Op), E);
    }

    event void Timer.fired (route_state_t State)
    {
    }

    event void Prot.got_explore (const herp_opinfo_t *Info, am_addr_t Prev,
                                 uint16_t HopsFromSrc)
    {
    }

    event void Prot.got_build (const herp_opinfo_t *Info, am_addr_t Prev,
                               uint16_t HopsFromDst)
    {
    }

    event void RTab.deliver (herp_opid_t OpId, rt_res_t Res, am_addr_t To,
                             const rt_route_t *Route)
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

