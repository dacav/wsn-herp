
 #include <ProtocolP.h>

module DumpAMP {

    provides {
        interface AMSend;
        interface Receive;
    }

    uses {
        interface AMSend as SubAMSend;
        interface Receive as SubReceive;
    }

}

implementation {

    static void dump_message (message_t *Msg) {
        herp_msg_t *HMsg;
        header_t *Hdr;
        const char * StrRep;

        HMsg = call SubAMSend.getPayload(Msg, sizeof(herp_msg_t));

        Hdr = &HMsg->header;
        switch (Hdr->op.type) {
            case PATH_EXPLORE:
                StrRep = "PATH_EXPLORE";
                break;

            case PATH_BUILD:
                StrRep = "PATH_BUILD";
                break;

            case USER_DATA:
                StrRep = "USER_DATA";
                break;

            default:
                StrRep = "WTF?";
        }
        dbg("Prot", "\tSrc=%d (OpId=%d)\n", Hdr->from, Hdr->op.id);
        dbg("Prot", "\tDst=%d\n", Hdr->to);
        dbg("Prot", "\tType=%s\n", StrRep);
        if (Hdr->op.type != USER_DATA) {
            dbg("Prot", "\t\tPrev=%d\n", HMsg->data.path.prev);
            dbg("Prot", "\t\tHops=%d\n", HMsg->data.path.hop_count);
        }
    }

    command error_t AMSend.cancel(message_t *Msg) {
        return call SubAMSend.cancel(Msg);
    }

    command void *AMSend.getPayload(message_t *Msg, uint8_t Size) {
        return call SubAMSend.getPayload(Msg, Size);
    }

    command uint8_t AMSend.maxPayloadLength() {
        return call SubAMSend.maxPayloadLength();
    }

    command error_t AMSend.send(am_addr_t Addr, message_t *Msg,
                                uint8_t Len) {
        error_t E;

        E = call SubAMSend.send(Addr, Msg, Len);
        dbg("Prot", "Sending message:\n");
        dump_message(Msg);
        dbg("Prot", "\tSendingTo=%d (%s)\n", Addr,
                    E == SUCCESS ? "Success" : "Fail");
        dbg("Prot", "--------------------------------------\n");
        return E;
    }

    event void SubAMSend.sendDone(message_t *Msg, error_t Error) {
        signal AMSend.sendDone(Msg, Error);
    }

    event message_t * SubReceive.receive (message_t *Msg, void * Payload,
                                       uint8_t Len) {
        dbg("Prot", "Received message:\n");
        dump_message(Msg);
        dbg("Prot", "--------------------------------------\n");

        return signal Receive.receive(Msg, Payload, Len);
    }

}
