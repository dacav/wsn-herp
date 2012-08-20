
 #include <ProtocolP.h>

generic configuration ProtocolC (uint8_t MSG_POOL_SIZE) {

    provides {
        interface Protocol;

        interface SplitControl as AMControl;
        interface Packet;
    }

}

implementation {

    components
        new AMSenderC(HERP_MSG),
        new AMReceiverC(HERP_MSG),
        new PoolC(message_t, MSG_POOL_SIZE),
        ActiveMessageC,
        ProtocolP;

    ProtocolP.Send -> AMSenderC;
    ProtocolP.Receive -> AMReceiverC;
    ProtocolP.SubPacket -> AMSenderC;
    ProtocolP.MsgPool -> PoolC;

    AMControl = ActiveMessageC;
    Protocol = ProtocolP;
    Packet = ProtocolP;

}
