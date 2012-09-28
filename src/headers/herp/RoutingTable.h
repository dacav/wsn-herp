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
