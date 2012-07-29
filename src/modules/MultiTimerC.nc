
 #include "MultiTimer.h"

generic configuration MultiTimer (typedef event_data_t,
                                  uint16_t QUEUE_SIZE) {
    provides {
        interface MultiTimer<event_data_t>;
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
