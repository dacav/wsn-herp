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

    uses interface MultiTimer<int>;
}

implementation
{
    int x, y, z;    // Replaced by Pool items IRL

    event void MultiTimer.fired (int *val) {
        dbg("Out", "Got event %d at time %d\n", *val, call Timer.getNow());

        (*val)++;
        call MultiTimer.schedule(128, val);
    }

    event void Boot.booted()  {
        x = 10;
        y = 20;

        call MultiTimer.schedule(128, &x);
        call MultiTimer.schedule(256, &y);
    }

    event message_t * Receive.receive (message_t *Msg, void *Payload,
                                       uint8_t Len) {
        return Msg;
    }

    event void RadioControl.startDone (error_t E) {
    }

    event void RadioControl.stopDone (error_t E) {
    }

    event void Timer.fired () {
    }

    event void Send.sendDone (message_t *Msg, error_t E) {
    }

}

