
 #include <RoutingTableP.h>
 #include <Types.h>

 #include <assert.h>
 #include <string.h>

module RoutingTableP {

    provide {
        interface RoutingTable[herp_opid_t OpId] as RTab;
    }

    use {
        interface HashTable <am_addr_t, struct routes> Table;
        interface Queue<deliver_t> as Delivers;
        interface Pool<struct subscr_item> as SubscrPool;

        // interface MultiTimer ...
    }

}

implementation {

    event hash_index_t Table.key_hash (const am_addr_t *Key) {
        return *Key;
    }

    event bool Table.key_equal (const am_addr_t *Key1, const am_addr_t *Key2) {
        return *Key1 == *Key2;
    }

    event error_t Table.value_init (const am_addr_t *Key, routes_t *Val) {
        int i;

        Val->subscr = NULL;
        for (i = 0; i < HERP_MAX_ROUTES; i ++) {
            memset((void *)Val, 0, sizeof(routes_t));
            Val->routes[i].target = *Key;
            Val->routes[i].sched = NULL;
            Val->routes[i].state = DEAD;
        }

        return SUCCESS;
    }

    event void Entries.value_dispose (const am_addr_t *Key, herp_rtentry_t *Val) {
        int i;

        while (Val->subscr) {
            subscr_item_t Item;

            Item = Val->subscr;
            Val->subscr = Item->next;

            call SubscrPool.put(Item);
        }

        #if 0
        for (i = 0; i < HERP_MAX_ROUTES; i ++) {
            herp_rtentry_t Entry = &(Val->routes[i]);

            if (Entry->sched != NULL) {
                call MultiTimer.nullify(Entry->sched);
                Entry->sched = NULL;
            }
        }
        #endif

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
            if ((post deliver_task()) == 0) {
                call Delivers.dequeue();
                return FALSE;
            }
        }

        return TRUE;
    }

    static bool subscribe (herp_opid_t Id, herp_rtentry_t Routes) {
        subscr_item_t ListItem;

        ListItem = call SubscrPool.get();
        if (ListItem == NULL) return FALSE;

        ListItem->next = Routes->subscr;
        Routes->subscr = ListItem;

        return TRUE;
    }

    command herp_rtres_t RTab.get_route[herp_opid_t OpId] (am_addr_t Node, herp_rtentry_t *Out) {
        routes_t Routes;
        herp_rtentry_t Seasoned, Fresh, Building;
        int i;

        *Out = NULL;

        Routes = call Table.get_data(&Node, FALSE);
        if (Routes == NULL) return HERP_RT_ERROR;

        Seasoned = NULL;
        Fresh = NULL;

        /* Scan the routes for the Target Node, collect useful records. */
        for (i = 0; i < HERP_MAX_ROUTES && Fresh == NULL; i ++) {
            herp_rtentry_t E;

            E = &(Routes->entries[i]);
            switch (E->state) {
                case DEAD:
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

        /* We have no record at all. Ask the caller to search for a
         * route by using the Reach message. */
        return HERP_RT_REACH;
    }

    command const herp_rthop_t * RTab.get_hop[herp_opid_t OpId] (const herp_rtentry_t Entry) {
        return &Entry->hop;
    }

    command herp_rtres_t RTab.flag_working[herp_opid_t OpId] (herp_rtentry_t Entry) {

        switch (Entry->state) {
            case DEAD:
                return HERP_RT_ERROR;
            case FRESH:
            case BUILDING:
                return HERP_RT_ALREADY;
            default:
                break;
        }

        Entry->owner = OpId;

        // TODO: set timeout, in order to avoid starving.
        //
        // call MultiTimer.nullify(Entry->sched)
        // Entry->sched = call MultiTimer.something(...)

        return HERP_RT_SUCCESS;

    }

	command herp_rtres_t RTab.refresh_route[herp_opid_t OpId] (herp_rtentry_t Entry, const herp_rthop_t *Hop) {

        if (Entry->state != SEASONED || Entry->owner != OpId) {
            return HERP_RT_ERROR;
        }

        Entry->state = FRESH;
        memcpy((void *)&Entry->hop, (const void *)Hop,
                sizeof(herp_rthop_t));

        // TODO: reset timer
        
        return enqueue(OpId, Entry) ? HERP_RT_SUBSCRIBED : HERP_RT_ERROR;
    }

    command herp_rtres_t RTab.drop_route[herp_opid_t OpId] (herp_rtentry_t *Entry) {
        if (Entry->state != SEASONED || Entry->owner != OpId) {
            return HERP_RT_ERROR;
        }
        Entry->state = DEAD;
        return call RTab.get_route[OpId](Entry->target, Entry) {
    }

    task void deliver_task () {
        deliver_t D;
        herp_rthop_t Hop;

        if (call Delivers.empty()) return;
        D = call Delivers.dequeue();

        Hop = NULL;
        if (D.entry->state == FRESH) {
            herp_rtentry_t Entry;

            Hop = &(D.entry->hop);

            Entry = call Entries.get_data(&D.entry->target, TRUE);
            if (Entry && Entry->subscr) {
                subscr_item_t Subscr;

                Subscr = Entry->subscr;
                Entry->subscr = Subscr->next;
                enqueue(Subscr->id, D.entry);
                call SubscrPool.put(Subscr);
            }

        }

        if (!call Delivers.empty()) post deliver_task();

        call RTab.deliver[D.id](Hop ? HERP_RT_SUCCESS : HERP_RT_RETRY,
                                D.entry->target, Hop);
    }

}
