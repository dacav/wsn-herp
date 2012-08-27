
 #include <Protocol.h>

configuration HerpAppC {}

implementation {

    components MainC, HerpC;
    components new RoutingC(5);

    HerpC.Send -> RoutingC;
    HerpC.Receive -> RoutingC;
    HerpC -> MainC.Boot;
    HerpC.Radio -> RoutingC;
    HerpC.Packet -> RoutingC;

}

