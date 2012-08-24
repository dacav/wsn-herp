#ifndef ROUTING_PRIV_H
#define ROUTING_PRIV_H

#include <message.h>

#include <RoutingTable.h>
#include <Protocol.h>

typedef enum {
    SEND    = 0,
    ROUTE   = 1,
    PAYLOAD = 2
} op_type_t;

typedef enum {
    START           = 0,
    EXPLORE_SENDING = 1,
    EXPLORE_SENT    = 2,
    WAIT_ROUTE      = 3,
    WAIT_TASK       = 4
} op_phase_t;

typedef struct route_state {
    struct {
        uint8_t type    : 2;    // op_type_t
        uint8_t phase   : 6;    // op_phase_t
    } op;

    herp_rtroute_t job;
    sched_item_t sched;

    union {
        struct {
            message_t *msg;
            uint8_t len;
        } send;
        struct {
            am_addr_t prev;
            uint16_t hops_from_src;  // <- useful for choice of best prev
            am_addr_t target;
        } route;
        struct {
            message_t *msg;
            uint8_t len;
            herp_opinfo_t info;
        } payload;
    };

} * route_state_t;

#endif // ROUTING_PRIV_H

