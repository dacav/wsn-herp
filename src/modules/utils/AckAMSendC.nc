
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
