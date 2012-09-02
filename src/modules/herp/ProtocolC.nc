
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
        new AckAMSendC(MSG_POOL_SIZE),
        StatAMSendC,
        ActiveMessageC,
        ProtocolP;

    AckAMSendC.SubAMSend -> AMSenderC;
    AckAMSendC.PacketAcknowledgements -> AMSenderC;
    AckAMSendC.Packet -> AMSenderC;
    AckAMSendC.AMPacket -> AMSenderC;

#ifdef DUMP
    components DumpAMP;

    DumpAMP.SubAMSend -> AckAMSendC;
    DumpAMP.SubReceive -> AMReceiverC;
    StatAMSendC.SubAMSend -> DumpAMP;
    ProtocolP.Receive -> DumpAMP;
#else
    StatAMSendC.SubAMSend -> AckAMSendC;
    ProtocolP.Receive -> AMReceiverC;
#endif

    ProtocolP.Send -> StatAMSendC;
    ProtocolP.SubPacket -> AMSenderC;
    ProtocolP.MsgPool -> PoolC;

    AMControl = ActiveMessageC;
    Protocol = ProtocolP;
    Packet = ProtocolP;
    TimerDelay = StatAMSendC;

}
