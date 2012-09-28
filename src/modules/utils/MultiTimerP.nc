/*
   Copyright 2012 Giovanni [dacav] Simoni


   This file is part of HERP. HERP is free software: you can redistribute
   it and/or modify it under the terms of the GNU General Public License
   as published by the Free Software Foundation, either version 3 of the
   License, or (at your option) any later version.

   This program is distributed in the hope that it will be useful, but
   WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   General Public License for more details.

   You should have received a copy of the GNU General Public License along
   with this program.  If not, see <http://www.gnu.org/licenses/>.

 */


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

    static inline uint32_t get_now ()
    {
        return call BaseTimer.getNow();
    }

    command error_t Init.init ()
    {
        sched_item_t Item;

        sched = NULL;

        while (!call Pool.empty()) {
            Item = call Pool.get();
            Item->next = sched;
            sched = Item;
        }

        while (sched != NULL) {
            Item = sched;
            sched = Item->next;
            Item->valid = 0;
            call Pool.put(Item);
        }

        return SUCCESS;
    }

    default event void MultiTimer.fired[herp_opid_t] (event_data_t *) {}

    command sched_item_t MultiTimer.schedule[herp_opid_t opid] (uint32_t T, event_data_t *D)
    {
        sched_item_t fresh;
        sched_item_t cursor, pr;
        uint32_t now;

        fresh = call Pool.get();
        assert(fresh != NULL);      // TODO: remove
        if (fresh == NULL) {
            return NULL;
        }
        assert(fresh->valid == 0);
        fresh->valid = 1;

        now = get_now();

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

    command void MultiTimer.nullify[herp_opid_t opid] (sched_item_t E)
    {
        sched_item_t nx;

        assert(E->id == opid);

        nx = E->next;
        if (E == sched) {
            if (nx) {
                nx->prev = NULL;
                call BaseTimer.startOneShot(nx->time - get_now());
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

        assert(E->valid);
        E->valid = 0;
        call Pool.put(E);
    }

    event void BaseTimer.fired ()
    {
        uint32_t now;

        assert(sched != NULL);

        now = sched->time;
        do {
            sched_item_t e;
            event_data_t *ed;

            e = sched;
            sched = sched->next;

            ed = (event_data_t *) e->store;

            assert(e->valid);
            signal MultiTimer.fired[e->id](ed);
            e->valid = 0;
            call Pool.put(e);

        } while (sched && sched->time == now);

        if (sched) {
            sched->prev = NULL;
            call BaseTimer.startOneShot(sched->time - get_now());
        }
    }

}
