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


 #include <RoutingTableP.h>
 #include <Types.h>

 #include <assert.h>
 #include <string.h>

module RoutingTableP {

    provides interface RoutingTable as RTab;

    uses {
        interface HashTable <am_addr_t, struct rt_node> as Table;
        interface Queue<am_addr_t>;
        interface Pool<struct rt_subscr> as SubscrPool;
        interface MultiTimer<struct rt_entry>;
    }

}

implementation {

    static void scan (rt_node_t Node, rt_find_t Find)
    {
        int i;

        memset(Find, 0, sizeof(struct rt_find));
        for (i = 0; i < HERP_MAX_ROUTES; i ++) {
            rt_entry_t Entry = &Node->entries[i];

            switch (Entry->status) {
                case DEAD:
                    if (!Find->dead) Find->dead = Entry;
                    break;

                case FRESH:
                    if (!Find->fresh) Find->fresh = Entry;
                    break;

                case SEASONED:
                    if (!Find->seasoned) Find->seasoned = Entry;
                    break;

                default:
                    assert(FALSE);
            }
        }
    }

    static bool all_dead (rt_node_t Node)
    {
        int i;

        for (i = 0; i < HERP_MAX_ROUTES; i ++) {
            if (Node->entries[i].status != DEAD) return FALSE;
        }
        return TRUE;
    }

    static void what_to_deliver (rt_node_t Node, rt_res_t *Result,
                                 rt_route_t **Route)
    {
        rt_entry_t BestFresh;
        int i;

        BestFresh = NULL;
        for (i = 0; i < HERP_MAX_ROUTES; i ++) {
            rt_entry_t Entry = &Node->entries[i];

            if (Entry->status == FRESH && (!BestFresh ||
                BestFresh->route.hops > Entry->route.hops)) {

                BestFresh = Entry;
            }
        }

        if (BestFresh) {
            *Route = &BestFresh->route;
            *Result = RT_FRESH;
        } else {
            struct rt_find Found;

            scan(Node, &Found);

            if (Found.seasoned) {
                *Route = &Found.seasoned->route;
                *Result = RT_VERIFY;
            } else {
                assert(Found.dead);
                *Route = NULL;
                *Result = (Node->job_running)
                          ? RT_WORKING  /* Meaning: don't notify */
                          : RT_NONE;
            }
        }
    }

    task void check_node ()
    {
        assert(call Queue.size() > 0);

        do {
            am_addr_t Target = call Queue.dequeue();
            hash_slot_t Slot = call Table.get(&Target, TRUE);
            rt_node_t Node = call Table.item(Slot);

            if (Node == NULL) continue;
            assert(Node->target == Target);
            assert(Node->enqueued);
            Node->enqueued = 0;

            if (Node->subscrs) {
                struct {
                    rt_res_t result;
                    rt_route_t *route;
                } Deliver;

                what_to_deliver(Node, &Deliver.result, &Deliver.route);
                if (Deliver.result != RT_WORKING) do {
                    rt_subscr_t Sub = Node->subscrs;

                    Node->subscrs = Sub->nxt;
                    signal RTab.deliver(Sub->id, Deliver.result, Target,
                                        Deliver.route);

                    call SubscrPool.put(Sub);
                } while (Node->subscrs);
            }

            if (all_dead(Node) && !Node->job_running) {
                call Table.del(Slot);
            }

        } while (call Queue.size() > 0);
    }

    static void schedule_check (rt_node_t Node)
    {
        if (!Node->enqueued) {
            if (call Queue.enqueue(Node->target) != SUCCESS) {
                assert(FALSE);  // Sorry, more resources needed!
            }
            Node->enqueued = 1;

            if (call Queue.size() == 1) {
                post check_node();
            }
        }
    }

    command rt_res_t RTab.get_route (am_addr_t To, rt_route_t *Out)
    {
        rt_node_t Node;
        struct rt_find Found;

        Node = call Table.get_item(&To, TRUE);
        if (Node == NULL) return RT_NONE;

        scan(Node, &Found);

        if (Found.fresh) {
            *Out = Found.fresh->route;
            return RT_FRESH;
        }

        if (Node->job_running) {
            return RT_WORKING;
        }

        if (Found.seasoned) {
            *Out = Found.seasoned->route;
            return RT_VERIFY;
        }

        assert(Found.dead);

        if (!Node->enqueued) {
            schedule_check(Node);
        }

        return RT_NONE;
    }

    command rt_res_t RTab.promise_route (am_addr_t To)
    {
        rt_node_t Node;

        Node = call Table.get_item(&To, FALSE);
        if (Node == NULL) return RT_FAIL;
        if (Node->job_running) return RT_WORKING;
        Node->job_running = 1;

        return RT_OK;
    }

    command rt_res_t RTab.fail_promise (am_addr_t To)
    {
        rt_node_t Node;

        Node = call Table.get_item(&To, FALSE);
        if (Node == NULL) return RT_FAIL;
        if (!Node->job_running) return RT_FAIL;
        Node->job_running = 0;
        schedule_check(Node);

        return RT_OK;
    }

    static rt_entry_t select_worst (rt_node_t Node)
    {
        unsigned i;
        rt_entry_t Ret = &Node->entries[0];

        for (i = 1; i < HERP_MAX_ROUTES; i ++) {
            rt_entry_t Entry = &Node->entries[i];

            if (Entry->route.hops > Ret->route.hops) {
                Ret = Entry;
            }
        }

        return Ret;
    }

    static rt_entry_t select_same_hop (rt_node_t Node, am_addr_t FirstHop)
    {
        unsigned i;

        for (i = 0; i < HERP_MAX_ROUTES; i ++) {
            rt_entry_t Entry = &Node->entries[i];

            if (Entry->route.first == FirstHop && Entry->status != DEAD) {
                return Entry;
            }
        }

        return NULL;
    }

    static void set_timer (rt_entry_t Entry, uint32_t T)
    {
        if (Entry->sched != NULL) {
            call MultiTimer.nullify(Entry->sched);
        }
        if (T > 0) {
            Entry->sched = call MultiTimer.schedule(T, Entry);
            assert(Entry->sched);
        } else {
            Entry->sched = NULL;
        }
    }

    static inline void assign (rt_entry_t Entry, const rt_route_t *Route)
    {
#ifdef DUMP
        am_addr_t Target = Entry->ref->target;

        if (Entry->status != DEAD) {
            dbg("RTab", "Route for %d, deleted <%d, %d>\n", Target,
                Entry->route.first, Entry->route.hops);
        }
        dbg("RTab", "Route for %d, added <%d, %d>\n", Target,
            Route->first, Route->hops);
#endif
        Entry->route = *Route;
        Entry->status = FRESH;
        set_timer(Entry, HERP_RT_TIME_FRESH);
    }

    command rt_res_t RTab.add_route (am_addr_t To, const rt_route_t *Route)
    {
        rt_node_t Node;
        rt_entry_t Candidate;
        struct rt_find Found;

        Node = call Table.get_item(&To, FALSE);
        if (Node == NULL) return RT_FAIL;

        Candidate = select_same_hop(Node, Route->first);

        if (Candidate) {
            if (Route->hops >= Candidate->route.hops
                    && Candidate->status == FRESH) {
                /* Currently holding a better route! */
                Candidate = NULL;
            }
        } else {
            scan(Node, &Found);
            if (Found.dead) Candidate = Found.dead;
            else if (Found.seasoned) Candidate = Found.seasoned;
            else {
                Candidate = select_worst(Node);
                if (Route->hops >= Candidate->route.hops) {
                    Candidate = NULL;
                }
            }
        }

        if (Candidate) {
            assign(Candidate, Route);
            Node->job_running = 0;
            schedule_check(Node);
        }

        return RT_OK;
    }

    command rt_res_t RTab.drop_route (am_addr_t To, am_addr_t FirstHop)
    {
        rt_node_t Node;
        int i;

        Node = call Table.get_item(&To, TRUE);
        if (Node == NULL) return RT_FAIL;

        for (i = 0; i < HERP_MAX_ROUTES; i ++) {
            rt_entry_t Entry = &Node->entries[i];

            if (Entry->route.first == FirstHop) {
                Entry->status = DEAD;
                set_timer(Entry, 0);
            }
        }
        schedule_check(Node);

        return RT_OK;
    }

    command rt_res_t RTab.enqueue_for (am_addr_t To, herp_opid_t OpId)
    {
        rt_node_t Node;
        rt_subscr_t Sub;

        Node = call Table.get_item(&To, TRUE);
        if (Node == NULL) return RT_NOT_WORKING;
        if (!Node->job_running) return RT_NOT_WORKING;

        Sub = call SubscrPool.get();
        if (Sub == NULL) return RT_FAIL;

        Sub->id = OpId;
        Sub->nxt = Node->subscrs;
        Node->subscrs = Sub;

        return RT_OK;
    }

    event hash_index_t Table.key_hash (const am_addr_t *Key)
    {
        return *Key;
    }

    event bool Table.key_equal (const am_addr_t *Key1,
                                const am_addr_t *Key2)
    {
        return (*Key1) == (*Key2);
    }

    event error_t Table.value_init (const am_addr_t *Target, rt_node_t Node)
    {
        int i;

        memset((void *)Node, 0, sizeof(struct rt_node));
        Node->target = *Target;
        for (i = 0; i < HERP_MAX_ROUTES; i ++) {
            Node->entries[i].ref = Node;
        }

#ifdef DUMP
        dbg("RTab", "Entry for %d, created.\n", *Target);
#endif
        return SUCCESS;
    }

    event void Table.value_dispose (const am_addr_t *Target, rt_node_t Node)
    {
#ifndef NDEBUG
        int i;

        assert(Node->subscrs == NULL);
        assert(!Node->job_running);
        for (i = 0; i < HERP_MAX_ROUTES; i ++) {
            rt_entry_t Entry = &Node->entries[i];

            assert(Entry->sched == NULL);
            assert(Entry->status == DEAD);
        }
#endif
#ifdef DUMP
        dbg("RTab", "Entry for %d, destroyed.\n", *Target);
#endif
    }

    event void MultiTimer.fired (rt_entry_t Entry)
    {
        assert(Entry->sched != NULL);
        Entry->sched = NULL;

        switch (Entry->status) {

            case FRESH:
                Entry->status = SEASONED;
#ifdef DUMP
                dbg("RTab", "Route for %d, seasoned <%d, %d>\n",
                    Entry->ref->target,
                    Entry->route.first,
                    Entry->route.hops);
#endif
                set_timer(Entry, HERP_RT_TIME_SEASONED);
                break;

            case SEASONED:
                Entry->status = DEAD;
#ifdef DUMP
                dbg("RTab", "Route for %d, deleted <%d, %d>\n",
                    Entry->ref->target,
                    Entry->route.first,
                    Entry->route.hops);
#endif
                break;

            case DEAD:
            default:
                assert(FALSE);
        }

        schedule_check(Entry->ref);
    }

}
