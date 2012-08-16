
 #include <RoutingTableP.h>
 #include <Types.h>

 #include <assert.h>
 #include <string.h>

module RoutingTableP {

    provides interface RoutingTable as RTab[herp_opid_t OpId];

    uses {
        interface HashTable <am_addr_t, struct routes> as Table;
        interface Queue<deliver_t> as Delivers;
        interface Pool<struct subscr_item> as SubscrPool;

        interface MultiTimer<struct herp_rtentry>;
    }

}

implementation {

    static bool subscribe (herp_opid_t Id, routes_t Routes);
    static bool enqueue (herp_opid_t Id, herp_rtentry_t Entry);
    static void set_timer (herp_rtentry_t Entry, uint32_t Time);

    task void deliver_task ();

    event hash_index_t Table.key_hash (const am_addr_t *Key) {
        return *Key;
    }

    event bool Table.key_equal (const am_addr_t *Key1, const am_addr_t *Key2) {
        return *Key1 == *Key2;
    }

    event error_t Table.value_init (const am_addr_t *Key, routes_t Val) {
        int i;

        memset((void *)Val, 0, sizeof(routes_t));
        for (i = 0; i < HERP_MAX_ROUTES; i ++) {
            Val->entries[i].target = *Key;
            Val->entries[i].state = DEAD;
        }

        return SUCCESS;
    }

    event void Table.value_dispose (const am_addr_t *Key, routes_t Val) {
        int i;

        while (Val->subscr) {
            subscr_item_t Item;

            Item = Val->subscr;
            Val->subscr = Item->next;

            call SubscrPool.put(Item);
        }

        for (i = 0; i < HERP_MAX_ROUTES; i ++) {
            herp_rtentry_t Entry = &(Val->entries[i]);

            if (Entry->sched != NULL) {
                call MultiTimer.nullify(Entry->sched);
                Entry->sched = NULL;
            }
        }

    }

    event void MultiTimer.fired (herp_rtentry_t Entry) {

        dbg("Out", "Fired timer for %p:\n", Entry);

        Entry->sched = NULL;
        switch (Entry->state) {
            case DEAD:
                assert(0);  // WTF?
            case FRESH:
                dbg("Out", "\tFRESH to SEASONED\n");
                Entry->state = SEASONED;
                set_timer(Entry, HERP_RT_TIME_SEASONED);
                break;
            default:
                dbg("Out", "\t...DEAD\n");
                Entry->state = DEAD;
        }
    }

	command herp_rtres_t RTab.new_route[herp_opid_t OpId] (am_addr_t Node, const herp_rthop_t *Hop) {
        return HERP_RT_ERROR;   // TODO implement
    }

    command herp_rtres_t RTab.get_route[herp_opid_t OpId] (am_addr_t Node, herp_rtentry_t *Out) {
        routes_t Routes;
        herp_rtentry_t Seasoned, Fresh, Building, Dead;
        int i;

        Routes = call Table.get_item(&Node, FALSE);
        if (Routes == NULL) return HERP_RT_ERROR;

        Dead = NULL;
        Seasoned = NULL;
        Fresh = NULL;
        Building = NULL;

        /* Scan the routes for the Target Node, collect useful records. */
        for (i = 0; i < HERP_MAX_ROUTES && Fresh == NULL; i ++) {
            herp_rtentry_t E;

            E = &(Routes->entries[i]);
            switch (E->state) {
                case DEAD:
                    if (Dead == NULL) Dead = E;
                    break;
                case BUILDING:
                    if (Building == NULL) Building = E;
                    break;
                case FRESH:
                    if (Fresh == NULL) Fresh = E;
                    break;
                case SEASONED:
                    if (Seasoned == NULL) Seasoned = E;
                    break;
            }
        }

        if (Fresh) {
            /* Fresh record spotted, enqueue immediately in the delivery
             * system. */
            return enqueue(OpId, Fresh)
                   ? HERP_RT_SUBSCRIBED : HERP_RT_ERROR;
        }

        if (Building) {
            /* No fresh record, but at least someone is trying to build
             * a route. Subscribing for when the result will be
             * available. */
            return subscribe(OpId, Routes)
                   ? HERP_RT_SUBSCRIBED : HERP_RT_ERROR;
        }

        if (Seasoned) {
            /* We have only seasoned records. Ask the caller to verify the
             * first seasoned record fe found */
            *Out = Seasoned;
            return HERP_RT_VERIFY;
        }

        if (Dead) {
            /* We have no record at all. Ask the caller to search for a
             * route by using the Reach message. */
            *Out = Dead;
            return HERP_RT_REACH;
        }

        // Hit only if HERP_MAX_ROUTES == 0, which is nonsense...
        assert(0);
    }

    command const herp_rthop_t * RTab.get_hop[herp_opid_t OpId] (const herp_rtentry_t Entry) {
        return &Entry->hop;
    }

    command herp_rtres_t RTab.flag_working[herp_opid_t OpId] (herp_rtentry_t Entry) {

        switch (Entry->state) {
            case FRESH:
            case BUILDING:
                return HERP_RT_ALREADY;

            default:
                Entry->owner = OpId;
                Entry->state = BUILDING;
                set_timer(Entry, HERP_RT_TIME_BUILDING);

                return HERP_RT_SUCCESS;
        }
    }

	command herp_rtres_t RTab.update_entry[herp_opid_t OpId] (herp_rtentry_t Entry, const herp_rthop_t *Hop) {

        if (Entry->owner != OpId) return HERP_RT_ERROR;

        Entry->hop.first_hop = Hop->first_hop;
        Entry->hop.n_hops = Hop->n_hops;
        Entry->state = FRESH;
        set_timer(Entry, HERP_RT_TIME_FRESH);

        return enqueue(OpId, Entry) ? HERP_RT_SUBSCRIBED : HERP_RT_ERROR;
    }

    command herp_rtres_t RTab.drop_route[herp_opid_t OpId] (herp_rtentry_t *Entry) {

        herp_rtentry_t ToDrop = *Entry;

        if (ToDrop->state != SEASONED || ToDrop->owner != OpId) {
            return HERP_RT_ERROR;
        }
        ToDrop->state = DEAD;
        set_timer(ToDrop, 0);

        return call RTab.get_route[OpId](ToDrop->target, Entry);
    }

    task void deliver_task () {
        deliver_t D;
        herp_rthop_t *Hop;

        if (call Delivers.empty()) return;
        D = call Delivers.dequeue();

        Hop = NULL;
        if (D.entry->state == FRESH) {
            routes_t Routes;

            Hop = &(D.entry->hop);

            Routes = call Table.get_item(&D.entry->target, TRUE);
            if (Routes && Routes->subscr) {
                subscr_item_t Subscr;

                Subscr = Routes->subscr;
                Routes->subscr = Subscr->next;

                enqueue(Subscr->id, D.entry);
                call SubscrPool.put(Subscr);
            }

        }

        if (!call Delivers.empty()) post deliver_task();

        signal RTab.deliver[D.subscriber](
            Hop ? HERP_RT_SUCCESS : HERP_RT_RETRY,
            D.entry->target, Hop
        );
    }

    static bool enqueue (herp_opid_t Id, herp_rtentry_t Entry) {
        deliver_t D = {
            .subscriber = Id,
            .entry = Entry
        };

        if (call Delivers.enqueue(D) != SUCCESS) {
            return FALSE;
        }

        if (call Delivers.size() == 1) {
            /* The queue was empty, so there was no task. */
            if (post deliver_task()) {
                call Delivers.dequeue();
                return FALSE;
            }
        }

        return TRUE;
    }

    static bool subscribe (herp_opid_t Id, routes_t Routes) {
        subscr_item_t ListItem;

        ListItem = call SubscrPool.get();
        if (ListItem == NULL) return FALSE;

        ListItem->next = Routes->subscr;
        ListItem->id = Id;
        Routes->subscr = ListItem;

        return TRUE;
    }

    static void set_timer (herp_rtentry_t Entry, uint32_t Time) {
        if (Entry->sched) {
            call MultiTimer.nullify(Entry->sched);
        }
        Entry->sched = Time > 0 ? call MultiTimer.schedule(Time, Entry) : NULL;
    }

}
