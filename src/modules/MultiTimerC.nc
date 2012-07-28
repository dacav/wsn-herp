
 #include "MultiTimer.h"

generic configuration MultiTimer (typedef event_data_t,
                                  uint16_t QUEUE_SIZE) {
    provides {
        interface MultiTimer<event_data_t>
    }
}

implementation {
    components MainC,
               new MultiTimerP(event_data_t),
               new PoolC(struct sched_item),
               new TimerMilliC();

    MainC.SoftwareInit -> PoolC;

    TxOpsP.SlotUsed -> BitVectorC.BitVector;
    MultiTimer = MultiTimerP;
}
