#ifndef ROUTING_TABLE_H
#define ROUTING_TABLE_H

#include <AM.h>

typedef struct herp_rtentry * herp_rtentry_t;

typedef struct {
    am_addr_t first_hop;
    herp_rtroute_t entry;
} herp_rthop_t;

typedef enum {
    HERP_RT_ERROR       = -3,   /**< Error; */
    HERP_RT_ALREADY     = -2,   /**< Operation already running; */
    HERP_RT_RETRY       = -1,   /**< Retry later; */
    HERP_RT_SUCCESS     =  0,   /**< Operation Successful; */
    HERP_RT_REACH       =  1,   /**< Unknown node, reach it; */
    HERP_RT_VERIFY      =  2,   /**< Known node is old, verify it; */
    HERP_RT_SUBSCRIBED  =  3    /**< Operation enqueued for answer. */
} herp_rtres_t;

#endif // ROUTING_TABLE_H
