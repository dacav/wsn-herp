 #include <Timer.h>
 #include <AM.h>
 #include "TxOps.h"

module HerpC
{
    uses {
        interface Boot;
        interface Receive;
        interface AMSend as Send;
        interface Timer<TMilli> as Timer;
        interface SplitControl as RadioControl;
        interface Packet;
        interface AMPacket;
    }
}

implementation
{
    message_t message;
    nx_uint32_t *val;

    event void Boot.booted()  {
        val = (nx_uint32_t *) call Packet.getPayload(&message,
                                                     sizeof(nx_uint32_t));

        call RadioControl.start();
    }

    event message_t * Receive.receive (message_t *Msg, void *Payload,
                                       uint8_t Len) {

        nx_uint32_t *got = (nx_uint32_t *) Payload;
        am_addr_t who = call AMPacket.source(Msg);

        dbg("Out", "%d Msg from %d, content: %d\n",
            TOS_NODE_ID, who, *got);
        return Msg;
    }

    event void RadioControl.startDone (error_t E) {
        if (E != SUCCESS) {
            dbg("Out", "%d Radio error\n", TOS_NODE_ID);
        } else {
            dbg("Out", "%d Radio ready\n", TOS_NODE_ID);
            call Timer.startPeriodic(128);
        }
    }

    event void RadioControl.stopDone (error_t E) {
        dbg("Out", "%d Radio stopped\n", TOS_NODE_ID);
    }

    event void Timer.fired () {

        error_t e;

        dbg("Out", "%d Sending...\n", TOS_NODE_ID);
        e = call Send.send(AM_BROADCAST_ADDR, &message,
                           sizeof(nx_uint32_t));
        dbg("Out", "%d Send error? %d\n", TOS_NODE_ID, e != SUCCESS);
    }

    event void Send.sendDone (message_t *Msg, error_t E) {
        dbg("Out", "%d Sent? %d\n", TOS_NODE_ID, E != SUCCESS);
        if (E == SUCCESS) {
            (*val) ++;
        }
    }

}

