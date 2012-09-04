#ifndef CONSTANTS_H
#define CONSTANTS_H

#define HERP_MAX_ROUTES     2
#define HERP_MAX_NODES      11
#define HERP_MAX_HOPS       10

#define HERP_TIME_AVG_ALPHA 0.95
#define HERP_TIME_DEV_BETA  0.95
#define HERP_TIME_DEV_MULT  4

#define HERP_MAX_RETRY      3   /* After 3 failures give up */
#define HERP_MAX_ACK        5

/* Time constants (all expressed in milliseconds) */
#define HERP_DEFAULT_RTT    500 /* TODO: set reasonable value */

/* TODO: set also reasonable values */
#define HERP_RT_TIME_BUILDING   (5 * 1024) /* BUILDING to DEAD */
#define HERP_RT_TIME_FRESH      (3 * 1024) /* FRESH to SEASONED */
#define HERP_RT_TIME_SEASONED   (5 * 1024) /* SEASONED to DEAD */

#define HERP_MAX_OPERATIONS 20

#endif // CONSTANTS_H

