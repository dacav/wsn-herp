
 #include <RoutingTableP.h>
 #include <Types.h>

 #include <assert.h>
 #include <string.h>

module RoutingTableP {

    provides interface RoutingTable as RTab[herp_opid_t OpId];

    uses {
        interface HashTable <am_addr_t, struct herp_rtentry> as Table;
        interface Queue<herp_rtentry_t> as Delivers;
        interface Pool<struct subscr_item> as SubscrPool;
        interface MultiTimer<struct herp_rtroute>;
    }

}

implementation {

    /* -- Internal function prototypes -------------------------------- */

    static void scan (herp_rtentry_t Entry, scan_t *Out);
    static bool enqueue (herp_rtentry_t Entry);
    static bool subscribe (herp_rtentry_t Entry, herp_opid_t OpId);
    static void set_timer (herp_rtroute_t Route, uint32_t T);
    static void mark_building (herp_rtroute_t Route, herp_opid_t OpId);
    static void copy_hop (herp_rthop_t *Dst, const herp_rthop_t *Src);

    /* -- Events & Commands from interfaces --------------------------- */

    command herp_rtres_t RTab.get_route [herp_opid_t OpId](am_addr_t Node, herp_rtentry_t *Out) {
        herp_rtentry_t Entry;
        scan_t Found;

        Entry = call Table.get_item(&Node, FALSE);
        if (Entry == NULL) return HERP_RT_ERROR;
        scan(Entry, &Found);

        if (Found.fresh) {
            subscribe(Entry, OpId);
            enqueue(Entry);
            return HERP_RT_SUBSCRIBED;
        }

        if (Found.building) {
            subscribe(Entry, OpId);
            return HERP_RT_SUBSCRIBED;
        }

        *Out = Entry;
        return Found.seasoned ? HERP_RT_VERIFY : HERP_RT_REACH;
    }

    command herp_rtroute_t RTab.get_job [herp_opid_t OpId](herp_rtentry_t Entry) {
        scan_t Found;
        herp_rtroute_t Selected;

        scan(Entry, &Found);

        if (Found.fresh || Found.building) {
            return NULL;
        }

        Selected = Found.seasoned ? Found.seasoned : Found.dead;
        assert(Selected != NULL);
        mark_building(Selected, OpId);

        return Selected;
    }

	command herp_rtres_t RTab.new_route [herp_opid_t OpId](am_addr_t Node, const herp_rthop_t *Hop) {
        // TODO: write code here
        return HERP_RT_ERROR;
    }

	command herp_rtres_t RTab.update_route [herp_opid_t OpId](herp_rtroute_t Route, const herp_rthop_t *Hop) {

        herp_rtentry_t Entry;

        if (Route->state != BUILDING || Route->owner != OpId) {
            return HERP_RT_ERROR;
        }

        Route->state = FRESH;
        set_timer(Route, HERP_RT_TIME_FRESH);
        copy_hop(&Route->hop, Hop);

        Entry = Route->ref;
        return (subscribe(Entry, OpId) && enqueue(Entry))
               ? HERP_RT_SUBSCRIBED
               : HERP_RT_ERROR;
    }

    command herp_rtres_t RTab.drop_route [herp_opid_t OpId](herp_rtroute_t ToDrop) {
        herp_rtentry_t Entry;

        if (ToDrop->state != BUILDING || ToDrop->owner != OpId) {
            return HERP_RT_ERROR;
        }

        ToDrop->state = DEAD;
        set_timer(ToDrop, 0);
        Entry = ToDrop->ref;
        if (Entry->subscr) enqueue(Entry);

        return HERP_RT_SUCCESS;
    }

    event hash_index_t Table.key_hash (const am_addr_t *Key) {
        return *Key;
    }

    event bool Table.key_equal (const am_addr_t *Key1,
                                const am_addr_t *Key2) {
        return (*Key1) == (*Key2);
    }

    event error_t Table.value_init (const am_addr_t *Target,
                                    herp_rtentry_t Entry) {
        int i;

        memset((void *)Entry, 0, sizeof(herp_rtentry_t));
        Entry->target = *Target;

        for (i = 0; i < HERP_MAX_ROUTES; i ++) {
            Entry->routes[i].ref = Entry;
        }

        return SUCCESS;
    }

    event void Table.value_dispose (const am_addr_t *Target,
                                    herp_rtentry_t Entry) {
        int i;

        assert(Entry->subscr == NULL);

        for (i = 0; i < HERP_MAX_ROUTES; i ++) {
            herp_rtroute_t R = &Entry->routes[i];
           
            if (R->sched != NULL) {
                call MultiTimer.nullify(R->sched);
            }
        }
    }

    event void MultiTimer.fired (herp_rtroute_t Route) {
        int NextState;
        herp_rtentry_t Entry;

        switch (Route->state) {
            case BUILDING:
            case SEASONED:
                NextState = DEAD;
                Entry = Route->ref;
                if (Entry->subscr) enqueue(Entry);
                break;
            case FRESH:
                NextState = SEASONED;
                break;
            default:
                assert(0);  // WTF?
        }

        Route->sched = NULL;
        Route->state = NextState;
    }

    /* -- Deliver queue management ------------------------------------ */

    task void deliver_task () {
        herp_rtres_t Outcome;
        herp_rtentry_t Entry;
        herp_rthop_t *Hop;
        scan_t Found;

        assert(!call Delivers.empty());

        Entry = call Delivers.dequeue();
        if (!call Delivers.empty()) {
            post deliver_task();
        }

        Entry->enqueued = FALSE;
        if (Entry->subscr == NULL) return;

        scan(Entry, &Found);
        if (Found.fresh) {
            Outcome = HERP_RT_SUCCESS;
            Hop = &Found.fresh->hop;
        } else {
            Outcome = HERP_RT_RETRY;
            Hop = NULL;
        }

        do {
            subscr_item_t Sub = Entry->subscr;

            Entry->subscr = Sub->next;
            signal RTab.deliver[Sub->id](Outcome, Entry->target, Hop);
            call SubscrPool.put(Sub);
        } while (Entry->subscr);
    }

    /* -- Misc utility functions -------------------------------------- */

    static bool subscribe (herp_rtentry_t Entry, herp_opid_t OpId) {
        subscr_item_t New;

        New = call SubscrPool.get();
        if (New == NULL) return FALSE;

        New->next = Entry->subscr;
        New->id = OpId;
        Entry->subscr = New;

        return TRUE;
    }

    static bool enqueue (herp_rtentry_t Entry) {
        if (Entry->enqueued) return TRUE;

        if (call Delivers.enqueue(Entry) != SUCCESS) return FALSE;
        Entry->enqueued = TRUE;

        if (call Delivers.size() == 1) {
            if (post deliver_task()) return FALSE;
        }

        return TRUE;
    }

    static void scan (herp_rtentry_t Entry, scan_t *Out) {
        int i;
        const uint16_t start = Entry->scan_start;

        memset((void *)Out, 0, sizeof(scan_t));
        for (i = 0; i < HERP_MAX_ROUTES; i ++) {
            herp_rtroute_t R;

            R = &(Entry->routes[(start + i) % HERP_MAX_ROUTES]);
            switch (R->state) {
                case DEAD:
                    if (!Out->dead) Out->dead = R;
                    break;
                case BUILDING:
                    if (!Out->building) Out->building = R;
                    break;
                case FRESH:
                    if (!Out->fresh) Out->fresh = R;
                    break;
                case SEASONED:
                    if (!Out->seasoned) Out->seasoned = R;
                    break;
            }
        }

        Entry->scan_start ++;
    }

    static void set_timer (herp_rtroute_t Route, uint32_t T) {

        if (Route->sched) call MultiTimer.nullify(Route->sched);
        Route->sched = (T > 0) ? call MultiTimer.schedule(T, Route)
                               : NULL;
    }

    static void mark_building (herp_rtroute_t Route, herp_opid_t OpId) {
        Route->state = BUILDING;
        Route->owner = OpId;
        set_timer(Route, HERP_RT_TIME_BUILDING);
    }

    static void copy_hop (herp_rthop_t *Dst, const herp_rthop_t *Src) {
        memcpy((void *)Dst, (const void *)Src, sizeof(herp_rthop_t));
    }

}
