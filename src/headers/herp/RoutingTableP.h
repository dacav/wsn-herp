#ifndef ROUTING_TABLE_PRIV_H
#define ROUTING_TABLE_PRIV_H

#include <Constants.h>
#include <MultiTimer.h>

#include <RoutingTable.h>

struct herp_rtentry {
    am_addr_t target;
    herp_rthop_t hop;
    sched_item_t sched;
    herp_opid_t owner;
    enum {
        DEAD,
        BUILDING,
        FRESH,
        SEASONED
    } state;
};

typedef struct subscr_item {
    herp_opid_t id;
    struct subscr_item * next;
} * subscr_item_t;

typedef struct routes {
    herp_rtentry entries[HERP_MAX_ROUTES];
    subscr_item_t subscr;
} * routes_t;

typedef struct {
    herp_opid_t subscriber;
    herp_rtentry_t entry;
} deliver_t;

#endif // ROUTING_TABLE_PRIV_H
