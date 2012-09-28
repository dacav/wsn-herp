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

#ifndef PROTOCOL_PRIV_H
#define PROTOCOL_PRIV_H

#include <Protocol.h>

/* -- Message Formats ------------------------------------------------ */

/** Type identifiers for messages. */
typedef enum {
    PATH_EXPLORE  = 0x01, /**< Path discovery (broadcasted). */
    PATH_BUILD    = 0x04, /**< Reverse path building. */
    USER_DATA     = 0x08  /**< User payload messages. */
} op_t;

typedef nx_struct {

    /** Operation metadata */
    nx_struct {
        nx_uint8_t type;    /**< Type of operation */
        nx_uint8_t id;      /**< Identifier of the operation */
    } op;

    nx_am_addr_t from;      /**< Source node */
    nx_am_addr_t to;        /**< Destination node */

} header_t;

typedef nx_struct {
    header_t header;     /**< Header of the message */

    /** The union provides different structures, which are supposed to be
     * used dependently on the value of header.op.type */
    nx_union {
        nx_struct {
            nx_am_addr_t prev;      /**< Previous node */
            nx_uint16_t hop_count;  /**< Incremental with hops; */
        } path;
        nx_uint8_t user_payload[0]; /**< Transmission payload */
    } data;

} herp_msg_t;

#endif // PROTOCOL_PRIV_H

