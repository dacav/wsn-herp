
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

    static message_t * msg_dup (const message_t *Orig);
    static inline herp_msg_t * msg_unwrap (message_t *Msg, uint8_t Len);
    static inline void msg_copy (message_t *Dst, const message_t *Src);
    static void header_init (header_t *Hdr, op_t OpType, herp_opid_t OpId,
                             am_addr_t To);

    /* ---------------------------------------------------------------- */

    command error_t Protocol.send_verify (herp_opid_t OpId, am_addr_t Target,
                                          am_addr_t FirstHop) {
        message_t *New;
        herp_msg_t *HerpMsg;
        error_t RetVal;
        header_t *Hdr;

        New = call MsgPool.get();
        if (New == NULL) return ENOMEM;

        HerpMsg = msg_unwrap(New, sizeof(herp_msg_t));
        Hdr = &HerpMsg->header;
        header_init(Hdr, PATH_EXPLORE, OpId, Target);

        HerpMsg->data.path.hop_count = 0;
        HerpMsg->data.path.prev = TOS_NODE_ID;

        RetVal = call Send.send(FirstHop, New, sizeof(herp_msg_t));
        if (RetVal != SUCCESS) {
            call MsgPool.put(New);
        }

        return RetVal;
    }

    command error_t Protocol.send_reach (herp_opid_t OpId, am_addr_t Target) {
        return call Protocol.send_verify(OpId, Target, AM_BROADCAST_ADDR);
    }

    command error_t Protocol.send_build (herp_opid_t OpId,
                                         const herp_opinfo_t *Info,
                                         am_addr_t BackHop) {
        message_t *New;
        herp_msg_t *HerpMsg;
        error_t RetVal;
        header_t *Hdr;

        New = call MsgPool.get();
        if (New == NULL) return ENOMEM;

        HerpMsg = msg_unwrap(New, sizeof(herp_msg_t));
        Hdr = &HerpMsg->header;
        header_init(Hdr, PATH_BUILD, Info->ext_opid, Info->to);
        Hdr->from = Info->from;

        HerpMsg->data.path.hop_count = 0;
        HerpMsg->data.path.prev = TOS_NODE_ID;

        RetVal = call Send.send(BackHop, New, sizeof(herp_msg_t));
        if (RetVal != SUCCESS) {
            call MsgPool.put(New);
        }

        return RetVal;
    }

    command error_t Protocol.send_data (herp_opid_t OpId, am_addr_t Target,
                                        am_addr_t FirstHop, message_t *Msg,
                                        uint8_t MsgLen) {
        herp_msg_t *HerpMsg;
        error_t RetVal;
        header_t *Hdr;

        Msg = msg_dup(Msg);
        if (Msg == NULL) {
            return ENOMEM;
        }
        MsgLen += sizeof(header_t);
        HerpMsg = msg_unwrap(Msg, MsgLen);
        if (HerpMsg == NULL) {
            call MsgPool.put(Msg);
            return ESIZE;
        }
        Hdr = &HerpMsg->header;
        header_init(Hdr, USER_DATA, OpId, Target);

        /* Note: Payload is supposed to be already inserted, user message
         * is used direcly (the user gave us the message!). */

        RetVal = call Send.send(FirstHop, Msg, MsgLen);
        if (RetVal != SUCCESS){
            call MsgPool.put(Msg);
        }
        return RetVal;
    }

    static void forward (message_t * Msg, uint8_t Len, am_addr_t To) {
        herp_msg_t *HerpMsg;

        dbg("Out", "Forwarding to %d\n", To);

        Msg = msg_dup(Msg);
        HerpMsg = msg_unwrap(Msg, Len);
        if (HerpMsg == NULL) return;

        switch (HerpMsg->header.op.type) {
            case PATH_EXPLORE:
            case PATH_BUILD:
                HerpMsg->data.path.hop_count ++;
                HerpMsg->data.path.prev = TOS_NODE_ID;
            case USER_DATA:
                break;
        }

        if (call Send.send(To, Msg, Len) != SUCCESS) {
            call MsgPool.put(Msg);
        }
    }

    event message_t * Receive.receive (message_t *Msg, void * Payload,
                                       uint8_t Len) {
        herp_msg_t *HerpMsg = (herp_msg_t *) Payload;
        herp_opinfo_t Info;
        op_t Type;
        const am_addr_t *NextHop;
        message_t *Fwd;

        Info.ext_opid = HerpMsg->header.op.id;
        Info.from = HerpMsg->header.from;
        Info.to = HerpMsg->header.to;

        Type = HerpMsg->header.op.type;
        if (Type == USER_DATA) {
            herp_userdata_t Data = {
                .bytes = HerpMsg->data.user_payload,
                .len = Len - sizeof(header_t)
            };

            NextHop = signal Protocol.got_payload(&Info, &Data);
        } else {
            herp_proto_t Proto = {
                .prev = HerpMsg->data.path.prev,
                .hop_count = HerpMsg->data.path.hop_count
            };

            if (Type == PATH_EXPLORE) {
                NextHop = signal Protocol.got_explore(&Info, &Proto);
            } else {
                NextHop = signal Protocol.got_build(&Info, &Proto);
            }
        }

        if (NextHop) forward(Msg, Type, *NextHop);

        return Msg;
    }

    event void Send.sendDone (message_t *Msg, error_t E) {
        herp_msg_t *HerpMsg;
        herp_opid_t OpId;
        am_addr_t From;

        HerpMsg = msg_unwrap(Msg, call SubPacket.payloadLength(Msg));
        OpId = HerpMsg->header.op.id;
        From = HerpMsg->header.from;
        call MsgPool.put(Msg);

        if (From == TOS_NODE_ID) {
            /* This was an operation asked by the upper layer */
            signal Protocol.done(OpId, E);
        }
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

    static inline herp_msg_t * msg_unwrap (message_t *Msg, uint8_t Len) {

        call SubPacket.setPayloadLength(Msg, Len);
        return (herp_msg_t *) call SubPacket.getPayload(Msg, Len);
    }

    static void header_init (header_t *Hdr, op_t OpType, herp_opid_t OpId,
                             am_addr_t To) {
        Hdr->op.type = OpType;
        Hdr->op.id = OpId;
        Hdr->from = TOS_NODE_ID;
        Hdr->to = To;
    }

    static inline void msg_copy (message_t *Dst, const message_t *Src) {
        memcpy((void *)Dst, (const void *)Src, sizeof(message_t));
    }

    static message_t * msg_dup (const message_t *Orig) {
        message_t *Ret;

        Ret = call MsgPool.get();
        if (Ret == NULL) return NULL;
        msg_copy(Ret, Orig);
        return Ret;
    }

}

