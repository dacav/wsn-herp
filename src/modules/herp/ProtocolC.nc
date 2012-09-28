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


 #include <ProtocolP.h>

generic configuration ProtocolC (uint8_t MSG_POOL_SIZE, am_id_t AM_ID) {

    provides {
        interface Protocol;
        interface TimerDelay;

        interface SplitControl as AMControl;
        interface Packet;
        interface AMPacket;
    }

}

implementation {

    components
        new AMReceiverC(AM_ID),
        new PoolC(message_t, MSG_POOL_SIZE),
        new TimerMilliC(),
        StatAMSendC,
        ProtocolP,
        ActiveMessageC;

#ifdef ACKED
    components new AMSenderC(AM_ID) as RealAMSenderC,
               new AckAMSendC(MSG_POOL_SIZE) as AMSenderC;

    AMSenderC.SubAMSend -> RealAMSenderC;
    AMSenderC.PacketAcknowledgements -> RealAMSenderC;
    AMSenderC.SubPacket -> RealAMSenderC;
    AMSenderC.SubAMPacket -> RealAMSenderC;
#else
    components new AMSenderC(AM_ID);
#endif

#ifdef DUMP
    components DumpAMP;

    DumpAMP.SubAMSend -> AMSenderC;
    DumpAMP.SubReceive -> AMReceiverC;
    StatAMSendC.SubAMSend -> DumpAMP;
    ProtocolP.Receive -> DumpAMP;
#else
    StatAMSendC.SubAMSend -> AMSenderC;
    ProtocolP.Receive -> AMReceiverC;
#endif

    ProtocolP.Send -> StatAMSendC;
    ProtocolP.SubPacket -> AMSenderC;
    ProtocolP.MsgPool -> PoolC;

    AMControl = ActiveMessageC;
    Protocol = ProtocolP;
    Packet = ProtocolP;
    AMPacket = AMSenderC;
    TimerDelay = StatAMSendC;

}
