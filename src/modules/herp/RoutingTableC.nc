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


 #include <Types.h>
 #include <RoutingTableP.h>
 #include <Constants.h>

generic configuration RoutingTableC (uint8_t MAX_OPS, uint8_t MAX_NODES) {

    provides interface RoutingTable;

}

implementation {

    components
        new HashTableC(am_addr_t, struct rt_node, MAX_NODES) as HTab,
        new QueueC(am_addr_t, MAX_OPS),
        new PoolC(struct rt_subscr, MAX_OPS),
        new MultiTimerC(struct rt_entry, HERP_MAX_ROUTES * MAX_OPS);

    components RoutingTableP;

    RoutingTableP.Table -> HTab;
    RoutingTableP.Queue -> QueueC;
    RoutingTableP.SubscrPool -> PoolC;
    RoutingTableP.MultiTimer -> MultiTimerC.MultiTimer[unique("Routing")];

    RoutingTable = RoutingTableP.RTab;

}

