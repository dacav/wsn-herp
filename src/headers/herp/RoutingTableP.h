#ifndef ROUTING_TABLE_PRIV_H
#define ROUTING_TABLE_PRIV_H

#include <Constants.h>
#include <MultiTimer.h>

#include <RoutingTable.h>

typedef enum {
    DEAD = 0,
    FRESH,
    SEASONED,
} rt_status_t;

typedef struct rt_node * rt_node_t;

typedef struct rt_entry {
    rt_route_t route;
    rt_status_t status;
    sched_item_t sched;
    rt_node_t ref;
} * rt_entry_t;

typedef struct rt_subscr {
    herp_opid_t id;
    struct subscr *nxt;
} * rt_subscr_t;

struct rt_node {
    am_addr_t target;
    struct rt_entry entries[HERP_MAX_ROUTES];
    subscr_t subscrs;
    uint8_t job_running : 1;
    uint8_t enqueued : 1;
};

typedef struct rt_find {
    rt_entry_t dead;
    rt_entry_t fresh;
    rt_entry_t seasoned;
} * rt_find_t;

#endif // ROUTING_TABLE_PRIV_H
