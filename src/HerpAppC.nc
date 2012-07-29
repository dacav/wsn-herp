 #include "herp.h"

configuration HerpAppC {}

implementation {

    components MainC, HerpC;
    components new AMSenderC(HERP_MSG);
    components new AMReceiverC(HERP_MSG);
    components new TimerMilliC() as Timer;
    components ActiveMessageC;

    components new MultiTimerC(int, 4);

    HerpC.MultiTimer -> MultiTimerC;

    HerpC -> MainC.Boot;
    HerpC.Receive -> AMReceiverC;
    HerpC.Send -> AMSenderC;
    HerpC.RadioControl -> ActiveMessageC;
    HerpC.Timer -> Timer;
    HerpC.Packet -> AMSenderC;
    HerpC.AMPacket -> AMSenderC;

}

