/*
   Copyright 2012 Giovanni [dacav] Simoni


   This file is part of HERP. HERP is free software: you can redistribute
   it and/or modify it under the terms of the GNU General Public License
   as published by the Free Software Foundation, either version 3 of the
   License, or (at your option) any later version.

   This program is distributed in the hope that it will be useful, but
   WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   General Public License for more details.

   You should have received a copy of the GNU General Public License along
   with this program.  If not, see <http://www.gnu.org/licenses/>.

 */

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
#define HERP_RT_TIME_FRESH      (3 * 1024) /* FRESH to SEASONED */
#define HERP_RT_TIME_SEASONED   (5 * 1024) /* SEASONED to DEAD */

#define HERP_MAX_OPERATIONS 20
#define HERP_MAX_LOOPBACK 3

#endif // CONSTANTS_H

