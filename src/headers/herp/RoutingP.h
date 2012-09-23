#ifndef ROUTING_PRIV_H
#define ROUTING_PRIV_H

#include <message.h>

#include <RoutingTable.h>
#include <Protocol.h>
#include <MultiTimer.h>
#include <OperationTable.h>

typedef enum {
    NEW = 0,
    SEND,
    EXPLORE,
    PAYLOAD
} optype_t;

typedef enum {
    START = 0,
    WAIT_PROT,
    WAIT_BUILD,
    WAIT_ROUTE,
    CLOSE       // upon next prot_done close everything
} phase_t;

typedef struct {
    message_t *msg;
    am_addr_t to;
    uint8_t retry;
} send_state_t;

typedef struct {
    herp_opinfo_t info;
    rt_route_t from_src;
    rt_route_t to_dst;
    sched_item_t sched;
} explore_state_t;

typedef struct {
    herp_opinfo_t info;
    message_t *msg;
    uint8_t len;
} payload_state_t;

typedef struct route_state {
    struct {
        herp_oprec_t rec;
        uint8_t type : 4;
        uint8_t phase : 4;
    } op;
    union {
        send_state_t send;
        explore_state_t explore;
        payload_state_t payload;
    };
} * route_state_t;

#endif // ROUTING_PRIV_H

