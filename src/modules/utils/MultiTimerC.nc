
 #include <MultiTimer.h>
 #include <Types.h>

generic configuration MultiTimerC (typedef event_data_t,
                                   uint16_t QUEUE_SIZE) {
    provides {
        interface MultiTimer<event_data_t> [herp_opid_t];
    }
}

implementation {
    components new MultiTimerP(event_data_t),
               new PoolC(struct sched_item, QUEUE_SIZE),
               new TimerMilliC();

    MultiTimerP.BaseTimer -> TimerMilliC;
    MultiTimerP.Pool -> PoolC;

    MultiTimer = MultiTimerP;
}
