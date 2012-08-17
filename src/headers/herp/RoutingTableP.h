#ifndef ROUTING_TABLE_PRIV_H
#define ROUTING_TABLE_PRIV_H

#include <Constants.h>
#include <MultiTimer.h>

#include <RoutingTable.h>

struct herp_rtroute {
    herp_rthop_t hop;
    herp_opid_t owner;
    herp_rtentry_t ref;
    sched_item_t sched;
    enum {
        DEAD = 0,
        BUILDING,
        FRESH,
        SEASONED
    } state;
};

typedef struct subscr_item {
    herp_opid_t id;
    struct subscr_item * next;
} * subscr_item_t;

struct herp_rtentry {
    struct herp_rtroute routes[HERP_MAX_ROUTES];
    uint16_t scan_start;

    subscr_item_t subscr;
    am_addr_t target;

    /* Flags */
    unsigned enqueued : 1;
    unsigned valid : 1;
};

typedef struct {
    herp_rtroute_t dead;
    herp_rtroute_t building;
    herp_rtroute_t fresh;
    herp_rtroute_t seasoned;
} scan_t;

#endif // ROUTING_TABLE_PRIV_H
