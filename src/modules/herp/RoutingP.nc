
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

    event error_t OpTab.data_init (route_state_t Routing)
    {
        memset((void *)Routing, 0, sizeof(struct route_state));
        return SUCCESS;
    }

    event void OpTab.data_dispose (route_state_t State)
    {
    }

    command error_t AMSend.send(am_addr_t Addr, message_t *Msg, uint8_t Len)
    {
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

    event void Timer.fired (route_state_t State)
    {
    }

    event void Prot.got_explore (const herp_opinfo_t *Info, am_addr_t Prev,
                                 uint16_t HopsFromSrc)
    {
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

