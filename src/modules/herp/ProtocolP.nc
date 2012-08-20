
 #include <ProtocolP.h>
 #include <Types.h>
 #include <AM.h>
 #include <assert.h>

module ProtocolP {

    provides {
        interface Protocol;
        interface Packet;
    }

    uses {
        interface AMSend as Send;
        interface Receive;
        interface Packet as SubPacket;

        interface Pool<message_t> as MsgPool;
    }

}

implementation {

    static inline herp_msg_t * msg_unwrap (message_t *Msg, uint8_t Size);
    static inline void msg_copy (message_t *Dst, const message_t *Src);
    static void header_init (header_t *Hdr, op_t OpType, herp_opid_t OpId,
                             am_addr_t Target);

    /* ---------------------------------------------------------------- */

    command error_t Protocol.send_reach (herp_opid_t OpId, am_addr_t Target) {
        message_t *New;
        herp_msg_t *HerpMsg;
        error_t RetVal;
        header_t *Hdr;

        int K = 0;

        New = call MsgPool.get();
        if (New == NULL) return ENOMEM;

        HerpMsg = msg_unwrap(New, sizeof(herp_msg_t));
        Hdr = &HerpMsg->header;
        header_init(Hdr, PATH_EXPLORE, OpId, Target);
        HerpMsg->data.path.hop_count = 0;
        HerpMsg->data.path.prev = TOS_NODE_ID;

        RetVal = call Send.send(AM_BROADCAST_ADDR, New, sizeof(herp_msg_t));
        if (RetVal != SUCCESS) {
            call MsgPool.put(New);
        }

        return RetVal;
    }

    command error_t Protocol.send_data (herp_opid_t OpId, am_addr_t Target,
                                        am_addr_t FirstHop, message_t *Msg,
                                        uint8_t MsgSize) {
        herp_msg_t *HerpMsg;
        error_t RetVal;
        header_t *Hdr;

        MsgSize += sizeof(header_t);
        HerpMsg = msg_unwrap(Msg, MsgSize);
        if (HerpMsg == NULL) {
            return ESIZE;
        }
        Hdr = &HerpMsg->header;
        header_init(Hdr, USER_DATA, OpId, Target);

        /* Note: Payload is supposed to be already inserted, user message
         * is used direcly (the user gave us the message!). */

        return call Send.send(FirstHop, Msg, MsgSize);
    }

    event message_t * Receive.receive (message_t *Msg, void * Payload,
                                       uint8_t Len) {
        herp_msg_t *HerpMsg = (herp_msg_t *) Payload;
        herp_opinfo_t Info;
        op_t Type;

        Info.ext_opid = HerpMsg->header.op.id;
        Info.from = HerpMsg->header.from;
        Info.to = HerpMsg->header.to;

        Type = HerpMsg->header.op.type;
        if (Type == USER_DATA) {
            herp_userdata_t Data = {
                .bytes = HerpMsg->data.user_payload,
                .len = Len - sizeof(header_t)
            };

            signal Protocol.got_payload(&Info, &Data);

        } else {
            herp_proto_t Proto = {
                .prev = HerpMsg->data.path.prev,
                .hop_count = HerpMsg->data.path.hop_count
            };

            if (Type == PATH_EXPLORE) {
                signal Protocol.got_explore(&Info, &Proto);
            } else {
                signal Protocol.got_build(&Info, &Proto);
            }
        }

        return Msg;
    }

    event void Send.sendDone (message_t *Msg, error_t E) {
        herp_msg_t *HerpMsg;

        HerpMsg = msg_unwrap(Msg, call SubPacket.payloadLength(Msg));
        if (HerpMsg->header.op.type != USER_DATA) {
            call MsgPool.put(Msg);
        }
        signal Protocol.done(HerpMsg->header.op.id, E);
    }

    command void Packet.clear(message_t *Msg) {
        call SubPacket.clear(Msg);
    }

    command void * Packet.getPayload(message_t *Msg, uint8_t Len) {
        herp_msg_t *Payload;

        Len += sizeof(header_t);
        Payload = (herp_msg_t *) call SubPacket.getPayload(Msg, Len);

        return (void *) Payload->data.user_payload;
    }

    command uint8_t Packet.maxPayloadLength() {
        return call SubPacket.maxPayloadLength() - sizeof(header_t);
    }

    command uint8_t Packet.payloadLength(message_t *Msg) {
        return call SubPacket.payloadLength(Msg) - sizeof(header_t);
    }

    command void Packet.setPayloadLength(message_t *Msg, uint8_t Len)  {
        call SubPacket.setPayloadLength(Msg, Len + sizeof(header_t));
    }

    /* -- Internal functions ----------------------------------------- */

    static inline herp_msg_t * msg_unwrap (message_t *Msg, uint8_t Size) {

        call SubPacket.setPayloadLength(Msg, Size);
        return (herp_msg_t *) call SubPacket.getPayload(Msg, Size);
    }

    static void header_init (header_t *Hdr, op_t OpType, herp_opid_t OpId,
                             am_addr_t Target) {
        Hdr->op.type = OpType;
        Hdr->op.id = OpId;
        Hdr->from = TOS_NODE_ID;
        Hdr->to = Target;
    }

    static inline void msg_copy (message_t *Dst, const message_t *Src) {
        memcpy((void *)Dst, (const void *)Src, sizeof(message_t));
    }

}

