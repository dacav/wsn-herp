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

#ifndef HERP_H
#define HERP_H

 #include <Types.h>
 #include <AM.h>
 #include <string.h>

typedef struct {
    herp_opid_t ext_opid;
    am_addr_t from;
    am_addr_t to;
} herp_opinfo_t;

static inline void opinfo_init (herp_opinfo_t *Info,
                                herp_opid_t ext_opid,
                                am_addr_t from,
                                am_addr_t to)
{
    Info->ext_opid = ext_opid;
    Info->from = from;
    Info->to = to;
}

static inline void opinfo_copy (herp_opinfo_t *Dst,
                                const herp_opinfo_t *Src)
{
    memcpy(Dst, Src, sizeof(herp_opinfo_t));
}

static inline bool opinfo_equal (const herp_opinfo_t *Info1,
                                 const herp_opinfo_t *Info2)
{
    return memcmp(Info1, Info2, sizeof(herp_opinfo_t)) == 0;
}

#endif // HERP_H

