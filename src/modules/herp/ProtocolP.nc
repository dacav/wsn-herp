
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
    static inline void header_init (header_t *Hdr, op_t OpType,
                                    const herp_opinfo_t *Info);

    /* ---------------------------------------------------------------- */

    command error_t Protocol.send_verify (herp_opid_t OpId, am_addr_t Target,
                                          am_addr_t FirstHop) {
        message_t *New;
        herp_msg_t *HerpMsg;
        error_t RetVal;
        header_t *Hdr;
        herp_opinfo_t Info = {
            .ext_opid OpId,
            .from = TOS_NODE_ID,
            .to = Target
        };

        New = call MsgPool.get();
        if (New == NULL) return ENOMEM;

        HerpMsg = msg_unwrap(New, sizeof(herp_msg_t));
        Hdr = &HerpMsg->header;
        header_init(Hdr, PATH_EXPLORE, &Info);

        HerpMsg->data.path.hop_count = 1;
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
        header_init(Hdr, PATH_BUILD, Info);

        HerpMsg->data.path.hop_count = 1;
        HerpMsg->data.path.prev = TOS_NODE_ID;

        RetVal = call Send.send(BackHop, New, sizeof(herp_msg_t));
        if (RetVal != SUCCESS) {
            call MsgPool.put(New);
        }

        return RetVal;
    }

    command error_t Protocol.init_user_msg (message_t *Msg, herp_opid_t OpId,
                                            am_addr_t Target) {
        herp_msg_t *HerpMsg;
        header_t *Hdr;
        herp_opinfo_t Info = {
            .ext_opid = OpId,
            .from = TOS_NODE_ID,
            .to = Target
        };

        HerpMsg = msg_unwrap(Msg, sizeof(header_t));
        if (HerpMsg == NULL) return FAIL;

        Hdr = &HerpMsg->header;
        header_init(Hdr, USER_DATA, &Info);

        return SUCCESS;
    }

    command error_t Protocol.send_data (message_t *Msg, uint8_t MsgLen,
                                        am_addr_t FirstHop) {
        error_t RetVal;

        Msg = msg_dup(Msg);
        if (Msg == NULL) return ENOMEM;
        MsgLen += sizeof(header_t);

        call SubPacket.setPayloadLength(Msg, MsgLen);
        RetVal = call Send.send(FirstHop, Msg, MsgLen);
        if (RetVal != SUCCESS){
            call MsgPool.put(Msg);
        }
        return RetVal;
    }

    event message_t * Receive.receive (message_t *Msg, void * Payload,
                                       uint8_t Len) {
        herp_msg_t *HerpMsg = (herp_msg_t *) Payload;
        herp_opinfo_t Info;
        op_t Type;

        Info.ext_opid = HerpMsg->header.op.id;
        Info.from = HerpMsg->header.from;
        Info.to = HerpMsg->header.to;

        dbg("Out", "Received\n");

        Type = HerpMsg->header.op.type;
        if (Type == USER_DATA) {

            Len -= sizeof(header_t);
            return signal Protocol.got_payload(&Info, Msg, Len);

        } else {
            am_addr_t Prev = HerpMsg->data.path.prev;
            uint16_t HopCount = HerpMsg->data.path.hop_count;

            if (Type == PATH_EXPLORE) {
                signal Protocol.got_explore(&Info, Prev, HopCount);
            } else {
                signal Protocol.got_build(&Info, Prev, HopCount);
            }

            return Msg;
        }
    }

    static error_t path_forward (const herp_opinfo_t *Info, op_t OpType, am_addr_t Next, uint16_t HopCount) {
        message_t *New;
        herp_msg_t *HerpMsg;
        error_t RetVal;
        header_t *Hdr;

        New = call MsgPool.get();
        if (New == NULL) return ENOMEM;

        HerpMsg = msg_unwrap(New, sizeof(herp_msg_t));
        Hdr = &HerpMsg->header;
        header_init(Hdr, OpType, Info);

        HerpMsg->data.path.prev = TOS_NODE_ID;
        HerpMsg->data.path.hop_count = HopCount + 1;

        RetVal = call Send.send(Next, New, sizeof(herp_msg_t));
        if (RetVal != SUCCESS) {
            call MsgPool.put(New);
        }

        return RetVal;
    }

    command error_t Protocol.fwd_explore (const herp_opinfo_t *Info, am_addr_t Next, uint16_t HopsFromSrc) {
        return path_forward(Info, PATH_EXPLORE, Next, HopsFromSrc);
    }

    command error_t Protocol.fwd_build (const herp_opinfo_t *Info, am_addr_t Prev, uint16_t HopsFromDst) {
        return path_forward(Info, PATH_BUILD, Prev, HopsFromDst);
    }

    command error_t Protocol.fwd_payload (const herp_opinfo_t *Info, am_addr_t Next, message_t *Msg, uint8_t Len) {
        error_t RetVal;

        Msg = msg_dup(Msg);
        if (Msg == NULL) return ENOMEM;

        RetVal = call Send.send(Next, Msg, Len);
        if (RetVal != SUCCESS) {
            call MsgPool.put(Msg);
        }

        return RetVal;
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

    static inline void header_init (header_t *Hdr, op_t OpType,
                                    const herp_opinfo_t *Info) {
        Hdr->op.type = OpType;
        Hdr->op.id = Info->ext_opid;
        Hdr->from = Info->from;
        Hdr->to = Info->to;
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

