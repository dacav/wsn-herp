
 #include <Constants.h>

module TimerDelayC {

    provides interface TimerDelay;
    uses interface Init;

}

implementation {

    uint32_t avg_RTT;

    command error_t Init.init () {
        avg_RTT = HERP_DEFAULT_RTT;
    }

    command uint32_t TimerDelay.for_verify (uint8_t Hops) {
        return avg_RTT * (Hops + 1);
    }

    command uint32_t TimerDelay.for_reach () {
        return avg_RTT * (HERP_MAX_HOPS + 1);
    }

    command void TimerDelay.record_RTT (uint32_t RoundTripTime) {
        avg_RTT *= HERP_RTT_ALPHA;
        avg_RTT += RoundTripTime * (1 - HERP_RTT_ALPHA);
    }

}
