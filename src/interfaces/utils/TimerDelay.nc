interface TimerDelay {

    /** The most appropriate timer for path verification.
     *
     * The time is estimated according to implementation-dependent
     * euristics.
     *
     * @param Hops The number of hops.
     *
     * @return The supposed round-trip-time for the given number of hops.
     */
    command uint32_t for_hops (uint8_t Hops);

}
