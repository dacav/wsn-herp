#ifndef ROUTING_PRIV_H
#define ROUTING_PRIV_H

#include <message.h>

#include <RoutingTable.h>
#include <Protocol.h>
#include <MultiTimer.h>
#include <OperationTable.h>

typedef enum {
    NEW = 0,
    SEND
} optype_t;

typedef enum {
    START = 0,
    WAIT_PROT
} phase_t;

typedef struct {
    message_t *msg;
    am_addr_t to;
    uint8_t retry;
} send_state_t;

typedef struct route_state {
    struct {
        herp_oprec_t rec;
        uint8_t type : 4;
        uint8_t phase : 4;
    } op;
    union {
        send_state_t send;
    };
} * route_state_t;

#endif // ROUTING_PRIV_H

