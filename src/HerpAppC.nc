
 #include <Protocol.h>

configuration HerpAppC {}

implementation {

    components
        MainC,
        HerpC,
        new RoutingC(5),
        new TimerMilliC(),
        RandomC,
        new PoolC(message_t, 10);

    HerpC.AMSend -> RoutingC;
    HerpC.AMPacket -> RoutingC;
    HerpC.Receive -> RoutingC;
    HerpC -> MainC.Boot;
    HerpC.Radio -> RoutingC;
    HerpC.Packet -> RoutingC;
    HerpC.Random -> RandomC;
    HerpC.Timer -> TimerMilliC;
    HerpC.Messages -> PoolC;

}

