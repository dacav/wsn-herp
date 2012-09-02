
 #include <Constants.h>
 #include <AckAMSendP.h>
 #include <string.h>
 #include <stdlib.h>

module AckAMSendP {

    provides {
        interface AMSend;
    }

    uses {
        interface AMSend as SubAMSend;
        interface AMPacket;
        interface Packet;
        interface PacketAcknowledgements as PacketAck;
        interface HashTable<message_t, send_info_t>;
        interface Queue<message_t *>;
    }

}

implementation {

    task void retry_task ();

    event error_t HashTable.value_init (const message_t *Key, send_info_t *Val)
    {
        Val->retry = HERP_MAX_ACK < (1<<6) ? HERP_MAX_ACK : (1<<6) - 1;
        Val->to_check = 1;
        Val->fresh = 1;

        return SUCCESS;
    }

    event void HashTable.value_dispose (const message_t *Key, send_info_t *Val) {}

    command error_t AMSend.cancel(message_t *Msg)
    {
        /* No time to implement this. However it's feasible:

           - Add a flag in the `send_info_t` data-type so that you know
             whether the message is sent by SubAMSend or not

           - If sent call SubAMSend.cancel(), check return value and
             delete the hashtable record if needed;

           - Else just delete the record (also change the task so that
             instead of asserting ignores an enqueued message not having a
             record in the hash table.

         */
        return FAIL;
    }

    command void *AMSend.getPayload(message_t *msg, uint8_t size)
    {
        return call SubAMSend.getPayload(msg, size);
    }

    command uint8_t AMSend.maxPayloadLength()
    {
        return call AMSend.maxPayloadLength();
    }

    static void end (message_t *Msg, hash_slot_t Slot, error_t E) {
        call HashTable.del(Slot);
        if (Msg) {
            signal AMSend.sendDone(Msg, E);
        }
    }

    static error_t enqueue (message_t *Msg) {
        error_t E;

        E = call Queue.enqueue(Msg);
        if (E == SUCCESS && call Queue.size() == 1) {
            /* Queue was empty, so no task is working for retrying to
             * send. */
            post retry_task();
        }

        return E;
    }

    static void retry (message_t *Msg) {
        send_info_t *Info;
        error_t E;
        hash_slot_t Slot = call HashTable.get(Msg, TRUE);

        assert(Slot != NULL);

        Info = call HashTable.item(Slot);
        E = FAIL;
        if (Info->retry) {
            Info->retry --;
            E = enqueue(Msg);
        }

        if (E != SUCCESS) {
            end(Msg, Slot, E);
        }
    }

    command error_t AMSend.send(am_addr_t Addr, message_t *Msg, uint8_t Len)
    {
        error_t EAck, ESend;
        hash_slot_t Slot;
        send_info_t *Info;

        /* Store the information inside the message, so we can get
         * it later (seriously, this mix of semantics is brain-damaged.
         * What the hell were they thinking? */
        call AMPacket.setDestination(Msg, Addr);
        call Packet.setPayloadLength(Msg, Len);

        Slot = call HashTable.get(Msg, FALSE);
        if (Slot == NULL) return EBUSY;
        Info = call HashTable.item(Slot);
        Info->fresh = 0;

        EAck = call PacketAck.requestAck(Msg);

        if (EAck == FAIL) {
            /* Ack not supported. Disable future checking and send
             * as it is. */
            Info->to_check = 0;
            ESend = call SubAMSend.send(Addr, Msg, Len);

        } else {

            if (EAck != EBUSY) {
                /* Ack is ok, we can try to send */
                ESend = call SubAMSend.send(Addr, Msg, Len);
            }

            if (EAck == EBUSY || ESend == EBUSY) {
                error_t EQueue;

                /* Either ACK or Sending facility is busy. Retry later */

                if (call Queue.size() == call Queue.maxSize()) {
                    /* Out of resources. */
                    end(NULL, Slot, EBUSY);
                    return EBUSY;
                }

                Info->retry --;
                Info->to_check = 1;

                EQueue = enqueue(Msg);
                assert(EQueue == SUCCESS);

                return SUCCESS;
            }

        }

        if (ESend != SUCCESS) {
            end(NULL, Slot, EBUSY);
        }

        return ESend;
    }

    event void SubAMSend.sendDone(message_t *Msg, error_t Error)
    {
        hash_slot_t Slot;
        send_info_t *Info;

        Slot = call HashTable.get(Msg, TRUE);
        assert(Slot != NULL);

        Info = call HashTable.item(Slot);

        assert(!Info->fresh);

        if (!Info->to_check || call PacketAck.wasAcked(Msg)) {
            end(Msg, Slot, Error);
        } else {
            retry(Msg);
        }
    }

    task void retry_task ()
    {
        message_t *Msg;
        hash_slot_t Slot;
        send_info_t *Info;
        uint8_t Size;
        error_t E;

        Size = call Queue.size();
        assert(Size > 0);
        Msg = call Queue.dequeue();
        if (Size > 1) {
            /* More messages in queue. Go on */
            post retry_task();
        }

        Slot = call HashTable.get(Msg, TRUE);
        assert(Slot != NULL);

        Info = call HashTable.item(Slot);
        assert(Info->to_check == 1 && Info->fresh == 0);

        E = call AMSend.send(
                call AMPacket.destination(Msg),
                Msg,
                call Packet.payloadLength(Msg)
            );

        switch (E) {
            case SUCCESS:
                /* Eventually we'll get SubAMSend.sendDone ... */
                break;

            default:
                /* The record has been destroyed already. */
                signal AMSend.sendDone(Msg, E);
                break;
        }
    }

    event hash_index_t HashTable.key_hash (const message_t *Key) {
        return (hash_index_t) call AMPacket.destination((message_t *)Key);
    }

    event bool HashTable.key_equal (const message_t *Key1, const message_t *Key2) {
        uint8_t Size1, Size2;

        /* Why casting? Those "programmers" forgot to set as const the
         * pointer which are not modified by the read-only calls! */
        if (call AMPacket.destination((message_t *)Key1) !=
            call AMPacket.destination((message_t *)Key2)) {
            return FALSE;
        }

        Size1 = call Packet.payloadLength((message_t *)Key1);
        Size2 = call Packet.payloadLength((message_t *)Key2);

        if (Size1 != Size2) {
            return FALSE;
        }

        return memcmp(call Packet.getPayload((message_t *)Key1, Size1),
                      call Packet.getPayload((message_t *)Key2, Size2),
                      Size1) == 0;
    }


}
