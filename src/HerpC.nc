
 #include <Timer.h>
 #include <AM.h>

 #include <Types.h>
 #include <Constants.h>
 #include <Protocol.h>

 #include <string.h>
 #include <assert.h>

 #define SENDER_NODE    3
 #define TARGET_NODE    5

module HerpC {

    uses {
        interface Boot;
        interface SplitControl as Radio;
        interface AMSend as Send;
        interface Packet;
        interface Receive;
    }

    uses interface Timer<TMilli>;
}

implementation {

    message_t GlobMsg;

    event void Boot.booted () {
        call Radio.start();
    }

    event message_t * Receive.receive (message_t *Msg, void * Payload, uint8_t Len) {
        dbg("Out", "Receive.receive(\"%s\", %d)\n",
            (char *)Payload, Len);
        return Msg;
    }

    event void Send.sendDone (message_t *Msg, error_t E) {
        assert(Msg == &GlobMsg);
        dbg("Out", "Sent: \"%s\" (Success? %d)\n",
            call Send.getPayload(Msg, 0), E == SUCCESS);
    }

    event void Radio.startDone (error_t Err) {
        dbg("Out", "Radio started\n");
        if (TOS_NODE_ID == SENDER_NODE) {
            call Timer.startOneShot(512);
        }
    }

    event void Timer.fired () {
        const char Text[] = "Silvia ti amo <3";
        void *Pay = call Packet.getPayload(&GlobMsg, sizeof(Text));

        dbg("Out", "Starting!\n");
        if (Pay == NULL) {
            dbg("Out", "Oh shit, too small!\n");
        } else {
            memcpy(Pay, Text, sizeof(Text));
            call Send.send(TARGET_NODE, &GlobMsg, sizeof(Text));
        }
    }

    event void Radio.stopDone (error_t Err) {
        dbg("Out", "Radio stopped (SUCCESS? %d)\n", Err == SUCCESS);
    }

}

