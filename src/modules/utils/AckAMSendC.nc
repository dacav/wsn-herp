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


 #include <AckAMSendP.h>

generic configuration AckAMSendC (uint8_t TRACK_SIZE) {

    provides {
        interface AMSend;
        interface Packet;
        interface AMPacket;
    }

    uses {
        interface AMSend as SubAMSend;
        interface PacketAcknowledgements;
        interface Packet as SubPacket;
        interface AMPacket as SubAMPacket;
    }

}

implementation {

    components AckAMSendP,
               new HashTableC(message_t, send_info_t, TRACK_SIZE),
               new QueueC(message_t *, TRACK_SIZE);

    AMSend = AckAMSendP;
    Packet = SubPacket;
    AMPacket = SubAMPacket;

    AckAMSendP.HashTable -> HashTableC;
    AckAMSendP.Queue -> QueueC;

    AckAMSendP.SubAMSend = SubAMSend;
    AckAMSendP.PacketAck = PacketAcknowledgements;
    AckAMSendP.Packet = SubPacket;
    AckAMSendP.AMPacket = SubAMPacket;

}
