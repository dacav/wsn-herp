
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
        new AMReceiverC(AM_ID),
        new PoolC(message_t, MSG_POOL_SIZE),
        new TimerMilliC(),
        StatAMSendC,
        ProtocolP,
        ActiveMessageC;

#ifdef ACKED
    components new AMSenderC(AM_ID) as RealAMSenderC,
               new AckAMSendC(MSG_POOL_SIZE) as AMSenderC;

    AMSenderC.SubAMSend -> RealAMSenderC;
    AMSenderC.PacketAcknowledgements -> RealAMSenderC;
    AMSenderC.Packet -> RealAMSenderC;
    AMSenderC.AMPacket -> RealAMSenderC;
#else
    components new AMSenderC(AM_ID);
#endif

#ifdef DUMP
    components DumpAMP;

    DumpAMP.SubAMSend -> AMSenderC;
    DumpAMP.SubReceive -> AMReceiverC;
    StatAMSendC.SubAMSend -> DumpAMP;
    ProtocolP.Receive -> DumpAMP;
#else
    StatAMSendC.SubAMSend -> AMSenderC;
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
