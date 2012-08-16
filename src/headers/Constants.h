#ifndef CONSTANTS_H
#define CONSTANTS_H

#define HERP_MAX_ROUTES     2
#define HERP_MAX_HOPS       10
#define HERP_RTT_ALPHA      0.95

/* Time constants (all expressed in milliseconds) */
#define HERP_DEFAULT_RTT    500 // TODO: set reasonable value

#define HERP_RT_TIME_BUILDING   10  /* BUILDING to DEAD */
#define HERP_RT_TIME_FRESH      10  /* FRESH to SEASONED */
#define HERP_RT_TIME_SEASONED   10  /* SEASONED to DEAD */

#endif // CONSTANTS_H

