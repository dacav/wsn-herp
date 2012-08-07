interface TimerDelay {

    /** The most appropriate timer for path verification.
     *
     * The time is computed according to implementation-dependent
     * euristics.
     *
     * @param Hops The number of hops supposed to be covered;
     *
     * @return The ideal timeout delay for the operation.
     */
    command uint32_t for_verify (uint8_t Hops);

    /** The most appropriate timer for node reaching.
     *
     * The time is computed according to implementation-dependent
     * euristics.
     *
     * @return The ideal timeout delay for the operation.
     */
    command uint32_t for_reach ();

    /** Record a round-trip-time sample.
     *
     * The data is internally used as parameter for building the output
     * timers.
     *
     * @param RoundTripTime The RTT for a message.
     */
    command void record_RTT (uint32_t RoundTripTime);

}
