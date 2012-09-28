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

#ifndef OPERATION_TABLE_H
#define OPERATION_TABLE_H

#include <Types.h>
#include <AM.h>

typedef struct herp_oprec * herp_oprec_t;

/** Operation table record */
struct herp_oprec {

    /** Identifiers of the operation */
    struct {
        herp_opid_t internal;   /**< Internal (local node); */
        herp_opid_t external;   /**< External (Internal for remote node); */
    } ids;

    am_addr_t owner;            /**< Owner node for the operation. */
    void * store;               /**< User data pointer */

};

typedef struct {
    am_addr_t node;
    herp_opid_t ext_id;
} herp_pair_t;

#endif // OPERATION_TABLE_H
