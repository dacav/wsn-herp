
 #include <ProtocolP.h>

generic configuration ProtocolC (uint8_t MSG_POOL_SIZE, am_id_t AM_ID) {

    provides {
        interface Protocol;

        interface SplitControl as AMControl;
        interface Packet;
    }

}

implementation {

    components
        new AMSenderC(AM_ID),
        new AMReceiverC(AM_ID),
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
