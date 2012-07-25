#include "Timer.h"

module HerpC
{
    uses interface Boot;
    uses interface Receive;
    uses interface AMSend as Send;
    uses interface Timer<TMilli> as Timer;
    uses interface SplitControl as RadioControl;
    uses interface Packet;
}

implementation
{
    event void Boot.booted()  {
        dbg("boot", "Application booted.\n");
    }

    event void Send.sendDone (message_t *msg, error_t e) {
    }

    event message_t * Receive.receive (message_t *msg, void *payload,
                                       uint8_t len) {
        return msg;
    }

    event void RadioControl.startDone (error_t e) {
    }

    event void RadioControl.stopDone (error_t e) {
    }

    event void Timer.fired () {
    }

}

