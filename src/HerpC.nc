
 #include <Timer.h>
 #include <AM.h>

 #include <Types.h>
 #include <Constants.h>
 #include <Protocol.h>

 #include <string.h>
 #include <assert.h>

typedef enum {
    HELLO_PING = 0,
    HELLO_PONG = 1
} hello_type_t;

typedef nx_struct {
    nx_uint8_t type;
    nx_uint16_t count;
} hello_msg_t;

#define MIN_TIME 512
#define MAX_TIME (512 + 1024)

#define N_NODES 10
#define BUDGET 10

module HerpC {

    uses {
        interface Boot;
        interface SplitControl as Radio;
        interface AMSend;
        interface AMPacket;
        interface Packet;
        interface Receive;
        interface Random;
        interface Timer<TMilli>;
        interface Pool<message_t> as Messages;
    }
}

implementation {

    uint16_t Sent;
    uint16_t Received;
    uint16_t Returned;

    uint8_t Budget;

    static uint16_t rand_int (uint16_t Min, uint16_t Max)
    {
        return Min + ((float)call Random.rand16())
                     / ((1<<16) - 1) * (Max - Min + 1);
    }

    static inline void print_stats ()
    {
        dbg("Stats", "Budget=%d, Sent=%d, Received=%d, Returned=%d\n",
            Budget, Sent, Received, Returned);
    }

    static void wake_up_random ()
    {
        if (Budget) {
            uint16_t T;

            Budget --;
            dbg("Out", "Waking up after random time...\n");
            T = rand_int(MIN_TIME, MAX_TIME);
            dbg("Out", "Time is %d\n", T);
            call Timer.startOneShot(T);
        } else {
            dbg("Stats", "Out of budget. I quit\n");
        }
    }

    static void prepare_hello (message_t *Msg, hello_type_t Type)
    {
        hello_msg_t *Payload;

        Payload = call Packet.getPayload(Msg, sizeof(hello_msg_t));
        Payload->type = Type;
        Payload->count = Sent;
    }

    static error_t send (hello_type_t What, am_addr_t To)
    {
        error_t E;
        message_t *M;

        M = call Messages.get();
        if (M == NULL) {
            dbg("Out", "!!! Out of resources!!!\n");
            return ENOMEM;
        }

        prepare_hello(M, What);
        E = call AMSend.send(To, M, sizeof(hello_msg_t));
        if (E != SUCCESS) {
            call Messages.put(M);
        }

        return E;
    }

    event void Boot.booted ()
    {
        Sent = 0;
        Received = 0;
        Budget = BUDGET;

        call Radio.start();
    }

    event message_t * Receive.receive (message_t *Msg, void * Payload,
                                       uint8_t Len)
    {
        hello_msg_t *Hello;
        am_addr_t Sender;

        assert(Len == sizeof(hello_msg_t));
        Hello = Payload;

        switch (Hello->type) {
            case HELLO_PING:
                Sender = call AMPacket.source(Msg);
                dbg("Out", "Receiving from %d\n", Sender);
                Received ++;
                send(HELLO_PONG, Sender);
                break;

            case HELLO_PONG:
                Returned ++;
                print_stats();
                break;

            default:
                assert(FALSE);
        }

        return Msg;
    }

    event void AMSend.sendDone (message_t *Msg, error_t E)
    {
        call Messages.put(Msg);
        dbg("Out", "Send done (%s)\n",
            E == SUCCESS ? "SUCCESS" : "PHAIL");

        if (E == SUCCESS) {
            Sent ++;
            print_stats();
        }
        wake_up_random();
        dbg("Out", "Goodbye!\n");
    }

    event void Radio.startDone (error_t Err)
    {
        if (Err != SUCCESS) {
            // should never happen in simulation, right? Right???
            assert(FALSE);
        } else {
            wake_up_random();
        }
    }

    event void Timer.fired ()
    {
        am_addr_t Target = rand_int(0, N_NODES - 1);

        if (Target == TOS_NODE_ID) {
            Target ++;
            Target %= N_NODES;
        }

        if (send(HELLO_PING, Target) == SUCCESS) {
            dbg("Out", "Sending to %d: SUCCESS\n", Target);
        } else {
            dbg("Out", "Sending to %d: FAIL\n", Target);
            wake_up_random();
        }
    }

    event void Radio.stopDone (error_t Err)
    {
    }

}

