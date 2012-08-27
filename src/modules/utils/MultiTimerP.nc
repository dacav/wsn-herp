
 #include <MultiTimer.h>
 #include <Types.h>

 #include <assert.h>

generic module MultiTimerP (typedef event_data_t) {
    provides {
        interface MultiTimer<event_data_t>[herp_opid_t];
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

    default event void MultiTimer.fired[herp_opid_t] (event_data_t *) {}

    command sched_item_t MultiTimer.schedule[herp_opid_t opid] (uint32_t T, event_data_t *D) {
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
        fresh->id = opid;
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

    command void MultiTimer.nullify[herp_opid_t opid] (sched_item_t E) {
        sched_item_t nx;

        assert(E->id == opid);

        nx = E->next;
        if (E == sched) {
            if (nx) {
                nx->prev = NULL;
                call BaseTimer.startOneShot(
                    nx->time - call BaseTimer.getNow()
                );
            } else if (call BaseTimer.isRunning()) {
                call BaseTimer.stop();
            }
            sched = nx;
        } else {
            E->prev->next = nx;
            if (nx) {
                nx->prev = E->prev;
            }
        }

        call Pool.put(E);
    }

    event void BaseTimer.fired () {
        uint32_t now;

        assert(sched != NULL);

        now = sched->time;
        do {
            sched_item_t e;
            event_data_t *ed;

            e = sched;
            sched = sched->next;

            ed = (event_data_t *) e->store;
            call Pool.put(e);

            signal MultiTimer.fired[e->id](ed);

        } while (sched && sched->time == now);

        if (sched) {
            sched->prev = NULL;
            now = call BaseTimer.getNow();
            call BaseTimer.startOneShot(sched->time - now);
        }
    }

}
