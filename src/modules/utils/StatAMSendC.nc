configuration StatAMSendC {

    provides {
        interface AMSend;
        interface TimerDelay;
    }
    
    uses {
        interface AMSend as SubAMSend;
    }

}

implementation {

    components MainC, StatAMSendP,
               new TimerMilliC();

    AMSend = StatAMSendP;
    TimerDelay = StatAMSendP;

    MainC.SoftwareInit -> StatAMSendP;
    StatAMSendP.Timer -> TimerMilliC;
    StatAMSendP.SubAMSend = SubAMSend;

}
