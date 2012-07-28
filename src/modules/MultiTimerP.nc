
 #include "MultiTimer.h"

generic module MultiTimerP (typedef event_data_t) {
    provides {
        interface MultiTimer<event_data_t>;
        interface Init;
    }
    uses {
        interface Timer<TMilli> as BaseTimer;
        interface Pool<struct sched_item>;
    }
}

implementation {

    sched_item_t sched;

    command error_t Init.init () {
        sched = NULL;
        return SUCCESS;
    }

    command sched_item_t MultiTimer.schedule (uint32_t T,
                                              event_data_t *D) {
        sched_item_t fresh;
        sched_item_t cursor, prev;

        fresh = call Pool.get();
        if (fresh == NULL) return NULL;

        T += call BaseTimer.getNow();
        cursor = sched;
        prev = NULL;

        while (cursor != NULL && cursor->time < T) {
            T -= cursor->time;
            prev = cursor;
            cursor = cursor->next;
        }

        if (cursor == sched) {
            
            /* Never moved. Insert in head (note: sched might be NULL) */
            fresh->next = sched;
            fresh->prev = NULL;
            if (sched) sched->prev = fresh;
            sched = fresh;

            /* As head is changed, fix the timer for first event */
            call BaseTimer.startOneShot(T);

        } else {

            /* Insert in between */
            fresh->next = cursor;
            if (cursor) cursor->prev = fresh;
            fresh->prev = prev;
            prev->next = fresh;

        }

        fresh->time = T;
        fresh->store = (void *) D;

        if ((cursor = fresh->next) != NULL) {
            cursor->time -= T;
        }

        return fresh;
    }

    command void nullify (sched_item_t E) {

        if (E->prev) E->prev->next = E->next;
        if (E->next) E->next->prev = E->prev;

        call Pool.put(E);
    }

    event void BaseTimer.fired () {
        sched_item_t e;
        event_data_t *ed;

        assert(sched != NULL);

        e = sched;
        sched = sched->next;
        if (sched) {
            sched->prev = NULL;
            call BaseTimer.startOneShot(sched->time);
        }

        ed = (event_data_t *) e->store;
        call Pool.put(e);
        signal MultiTimer.fired(ed);
    }

}
