interface TimerDelay {

    /** Time for reaching a node.
     *
     * This function yields the time required as round-trip-time to a node
     * which is `Hops` nodes distant. The time is estimated according to
     * implementation-dependent euristics.
     *
     * @param Hops The number of hops.
     *
     * @return The supposed round-trip-time for the given number of hops
     *         in milliseconds.
     */
    command uint32_t for_hops (uint8_t Hops);

    /** Time for reaching any node
     *
     * This function yields an estimate of the as round-trip-time to any
     * node in the network, regardless of the path.
     *
     * @return The required value in milliseconds.
     */
    command uint32_t for_any_node ();

}
