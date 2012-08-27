
 #include <Constants.h>
 #include <string.h>
 #include <stdlib.h>

typedef struct {
    float time;
    float diff;
} measure_t;

module StatAMSendP {

    provides {
        interface AMSend;
        interface TimerDelay;
        interface Init;
    }

    uses {
        interface AMSend as SubAMSend;
        interface Timer<TMilli>;
        //interface PacketAcknowledgments as PacketAck;
    }

}

implementation {

    struct {
        measure_t est;

        uint32_t send_time;
        bool valid;
    } Stats;

    command error_t Init.init () {
        Stats.valid = FALSE;
        Stats.send_time = 0;
        Stats.est.time = 0;
        return SUCCESS;
    }

    command uint32_t TimerDelay.for_hops (uint8_t Hops) {
        /* Forward trip + backward trip: multiply by 2 */
        return 2 * (Hops * Stats.est.time
                    + HERP_TIME_DEV_MULT * Stats.est.diff);
    }

    command uint32_t TimerDelay.for_any_node () {
        /* This is yielded just as based on static maximum number of nodes
         * in the network (see `Constants.h`). This is for sake of
         * simplicity.
         */
        return call TimerDelay.for_hops(HERP_MAX_NODES);
    }

    static void compute_stats () {
        uint32_t T = call Timer.getNow() - Stats.send_time;

        if (Stats.est.time == 0) {
            Stats.est.time = T;
            Stats.est.diff = 0;
        } else {
            measure_t Curr;

            Curr.time = HERP_TIME_AVG_ALPHA * Stats.est.time
                      + (1 - HERP_TIME_AVG_ALPHA) * (float)T;
            Curr.diff = HERP_TIME_DEV_BETA * Stats.est.diff
                      + (1 - HERP_TIME_DEV_BETA) * abs(Curr.time - T);

            Stats.est = Curr;
        }
    }

    command error_t AMSend.cancel(message_t *Msg)
    {
        error_t Ret = call SubAMSend.cancel(Msg);
        if (Ret == SUCCESS) {
            Stats.valid = FALSE;
        }
        return Ret;
    }

    command void *AMSend.getPayload(message_t *msg, uint8_t size)
    {
        return call SubAMSend.getPayload(msg, size);
    }

    command uint8_t AMSend.maxPayloadLength()
    {
        return call AMSend.maxPayloadLength();
    }

    command error_t AMSend.send(am_addr_t Addr, message_t *Msg, uint8_t Len)
    {
        error_t E;

        /* Note: This assumes that there can be only one sending running.
         *       I hope this is a reasonable assumption.
         */
        Stats.send_time = call Timer.getNow();
        E = call SubAMSend.send(Addr, Msg, Len);
        Stats.valid = (E == SUCCESS);
        return E;
    }

    event void SubAMSend.sendDone(message_t *Msg, error_t Error)
    {
        if (Stats.valid && Error == SUCCESS) {
            compute_stats();
        }
        signal AMSend.sendDone(Msg, Error);
    }

    event void Timer.fired () {}

}
