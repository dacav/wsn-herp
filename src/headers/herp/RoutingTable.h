#ifndef ROUTING_TABLE_H
#define ROUTING_TABLE_H

#include <AM.h>

typedef struct {
    am_addr_t first;
    uint8_t hops;
} rt_route_t;

typedef enum {
    RT_FAIL = -1,   /**< Failure */
    RT_OK = 0,      /**< Success */
    RT_NONE,        /**< No route for the required destination */
    RT_FRESH,       /**< The route is fresh */
    RT_VERIFY,      /**< The route must be verified */
    RT_WORKING,     /**< An operation is working on this route */
    RT_NOT_WORKING  /**< No operation is working on this route */
} rt_res_t;

#endif // ROUTING_TABLE_H
