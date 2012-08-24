
 #include <ProtocolP.h>

generic configuration ProtocolC (uint8_t MSG_POOL_SIZE, am_id_t AM_ID) {

    provides {
        interface Protocol;
        interface TimerDelay;

        interface SplitControl as AMControl;
        interface Packet;
    }

}

implementation {

    components
        new AMSenderC(AM_ID),
        new AMReceiverC(AM_ID),
        new PoolC(message_t, MSG_POOL_SIZE),
        new TimerMilliC(),
        StatAMSendC,
        ActiveMessageC,
        ProtocolP;

    StatAMSendC.SubAMSend -> AMSenderC;
    ProtocolP.Send -> StatAMSendC;
    ProtocolP.Receive -> AMReceiverC;
    ProtocolP.SubPacket -> AMSenderC;
    ProtocolP.MsgPool -> PoolC;

    AMControl = ActiveMessageC;
    Protocol = ProtocolP;
    Packet = ProtocolP;
    TimerDelay = StatAMSendC;

}
