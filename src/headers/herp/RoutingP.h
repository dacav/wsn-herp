#ifndef ROUTING_PRIV_H
#define ROUTING_PRIV_H

#include <message.h>

#include <RoutingTable.h>
#include <Protocol.h>

typedef enum {
    LOCAL = 0,
    REMOTE = 1
} op_type_t;

typedef enum {

    /* -- For local operations -- */
    START,
    EXPLORE_SENDING,
    EXPLORE_SENT,
    WAIT_ROUTE,
    EXEC_TASK,

    STOP

} op_phase_t;

typedef struct {
    uint8_t retry;

    struct {
        uint8_t type : 1;
        uint8_t phase : 7;
    } op;

    herp_rtroute_t job;

    union {
        struct {
            message_t *msg;
            uint8_t len;
        } send;
        struct {
            am_addr_t prev;
            uint16_t hops_from_src;
            am_addr_t target;
        } route;
    } data;
} * herp_routing_t;

#endif // ROUTING_PRIV_H

