
 #include "MultiTimer.h"
 #include <assert.h>

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
        sched_item_t cursor, pr;
        uint32_t now;

        fresh = call Pool.get();
        if (fresh == NULL) return NULL;

        now = call BaseTimer.getNow();

        cursor = sched;
        pr = NULL;

        T += now;
        while (cursor != NULL && cursor->time <= T) {
            pr = cursor;
            cursor = cursor->next;
        }

        fresh->time = T;
        fresh->store = (void *) D;

        if (cursor == sched) {
            
            /* Never moved. Insert in head (note: sched might be NULL) */
            fresh->next = sched;
            fresh->prev = NULL;
            if (sched) sched->prev = fresh;
            sched = fresh;

            /* As head is changed, fix the timer for first event */
            call BaseTimer.startOneShot(T - now);

        } else {

            /* Insert in between */
            fresh->next = cursor;
            if (cursor) cursor->prev = fresh;
            fresh->prev = pr;
            pr->next = fresh;

        }

        return fresh;
    }

    command void MultiTimer.nullify (sched_item_t E) {
        sched_item_t nx;

        nx = E->next;
        if (E == sched) {
            if (next) {
                nx->prev = NULL;
                call BaseTimer.startOneShot(
                    nx->time - call BaseTimer.getNow()
                );
            }
            sched = nx;
        } else {
            E->prev->next = nx;
            if (next) {
                nx->prev = E->prev;
            }
        }

        call Pool.put(E);
    }

    event void BaseTimer.fired () {

        assert(sched != NULL);

        do {
            sched_item_t e;
            event_data_t *ed;

            e = sched;
            sched = sched->next;
            if (sched) {
                uint32_t now = call BaseTimer.getNow();

                sched->prev = NULL;
                call BaseTimer.startOneShot(sched->time - now);
            }

            e->next = e->prev = NULL;
            ed = (event_data_t *) e->store;
            call Pool.put(e);

            signal MultiTimer.fired(ed);
        } while (sched && sched->time == 0);
    }

}
