
 #include <Protocol.h>

configuration HerpAppC {}

implementation {

    components MainC, HerpC;
    components new RoutingC(5);
    components new TimerMilliC();

    HerpC.Send -> RoutingC;
    HerpC.Receive -> RoutingC;
    HerpC -> MainC.Boot;
    HerpC.Radio -> RoutingC;
    HerpC.Packet -> RoutingC;
    HerpC.Timer -> TimerMilliC;

}

