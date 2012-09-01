generic configuration AckAMSendC (uint8_t TRACK_SIZE) {

    provides {
        interface AMSend;
    }

    uses {
        interface AMSend as SubAMSend;
        interface PacketAcknowledgements;
    }

}

implementation {

    components AckAMSendP,
               new HashTableC(message_t, send_info_t, TRACK_SIZE),
               new QueueC(message_t *, TRACK_SIZE);

    AMSend = AckAMSendP;

    AckAMSendP.HashTable -> HashTableC;
    AckAMSendP.Queue -> QueueC;

    AckAMSendP.SubAMSend = SubAMSend;
    AckAMSendP.PacketAck = PacketAcknowledgements;

}
