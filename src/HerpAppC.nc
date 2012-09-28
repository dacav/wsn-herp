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

 #include <Protocol.h>

configuration HerpAppC {}

implementation {

    components
        MainC,
        HerpC,
        new RoutingC(5),
        new TimerMilliC(),
        RandomC,
        new PoolC(message_t, 10);

    HerpC.AMSend -> RoutingC;
    HerpC.AMPacket -> RoutingC;
    HerpC.Receive -> RoutingC;
    HerpC -> MainC.Boot;
    HerpC.Radio -> RoutingC;
    HerpC.Packet -> RoutingC;
    HerpC.Random -> RandomC;
    HerpC.Timer -> TimerMilliC;
    HerpC.Messages -> PoolC;

}

