#ifndef ROUTING_PRIV_H
#define ROUTING_PRIV_H

#include <message.h>

#include <RoutingTable.h>
#include <Protocol.h>
#include <MultiTimer.h>

typedef enum {
    NEW     = 0,
    SEND    = 1,
    EXPLORE = 2,
    PAYLOAD = 3,
    COLLECT = 4
} op_type_t;

typedef enum {
    START           = 0,
    WAIT_ROUTE      = 1,
    WAIT_JOB        = 2,
    WAIT_PROT       = 3
} op_phase_t;

typedef struct {
    message_t *msg;
    am_addr_t target;
    uint8_t retry;
} send_state_t;

typedef struct {
    herp_rtroute_t job;         /**< NULL unless we've a running job wrt
                                     Routing Table */

    sched_item_t sched;         /**< NULL unless we've a running timer */

    am_addr_t prev;             /**< Node for Build forwarding (set to
                                     TOS_NODE_ID if the communication is
                                     local */

    am_addr_t propagate;        /**< Explore propagation address (may be
                                     AM_BROADCAST_ADDR. */

    uint16_t hops_from_src;     /**< Useful for choice of best prev; */

    herp_opinfo_t info;         /**< Context for information propagation. */

} explore_state_t;

typedef struct {
    message_t *msg;
    uint8_t len;
    herp_opinfo_t info;
} payload_state_t;

typedef struct route_state {
    struct {
        uint8_t type    : 4;    // op_type_t
        uint8_t phase   : 4;    // op_phase_t
    } op;

    herp_oprec_t op_rec;

    union {
        send_state_t send;
        explore_state_t explore;
        payload_state_t payload;
    };

} * route_state_t;

#endif // ROUTING_PRIV_H

