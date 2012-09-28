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


 #include <RoutingP.h>

generic configuration RoutingC(am_id_t AM_ID) {

    provides {
        interface AMSend;
        interface AMPacket;
        interface Receive;

        interface SplitControl as AMControl;
        interface Packet;
    }

}

implementation {

    components
        RoutingP,
        new ProtocolC(HERP_MAX_OPERATIONS, AM_ID),
        new OperationTableC(struct route_state, HERP_MAX_OPERATIONS),
        new RoutingTableC(HERP_MAX_OPERATIONS, HERP_MAX_NODES),
        new MultiTimerC(struct route_state, HERP_MAX_OPERATIONS),
        new PoolC(message_t, HERP_MAX_NODES),
        new QueueC(route_state_t, HERP_MAX_OPERATIONS) as RetryQueue,
        new QueueC(message_t *, HERP_MAX_LOOPBACK) as LoopBackQueue;

    AMSend = RoutingP;
    AMPacket = ProtocolC;
    Receive = RoutingP;
    AMControl = ProtocolC;
    Packet = ProtocolC;

    RoutingP.OpTab -> OperationTableC;
    RoutingP.RTab -> RoutingTableC;
    RoutingP.Prot -> ProtocolC.Protocol;
    RoutingP.Packet -> ProtocolC;
    RoutingP.AMPacket -> ProtocolC;
    RoutingP.TimerDelay -> ProtocolC;
    RoutingP.Timer -> MultiTimerC.MultiTimer[unique("HerpMT")];
    RoutingP.PayloadPool -> PoolC;
    RoutingP.RetryQueue -> RetryQueue;
    RoutingP.LoopBackQueue -> LoopBackQueue;

}
