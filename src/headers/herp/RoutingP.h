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
    PAYLOAD = 3
} op_type_t;

typedef enum {
    START           = 0,
    EXPLORE_SENDING = 1,
    EXPLORE_SENT    = 2,
    WAIT_ROUTE      = 3,
    EXEC_JOB        = 4
} op_phase_t;

typedef struct comm_state {
    herp_rtroute_t job;
    sched_item_t sched;
} * comm_state_t;

typedef struct {
    struct comm_state comm;
    message_t *msg;
    uint8_t len;
    am_addr_t target;
} send_state_t;

typedef struct {
    struct comm_state comm;
    am_addr_t prev;
    uint16_t hops_from_src;  // <- useful for choice of best prev
    herp_opinfo_t info;
} explore_state_t;

typedef struct {
    message_t *msg;
    uint8_t len;
    herp_opinfo_t info;
} payload_state_t;

typedef struct route_state {
    uint8_t restart;

    struct {
        uint8_t type    : 2;    // op_type_t
        uint8_t phase   : 6;    // op_phase_t
    } op;

    herp_opid_t int_opid;

    union {
        send_state_t send;
        explore_state_t explore;
        payload_state_t payload;
    };

} * route_state_t;

#endif // ROUTING_PRIV_H

