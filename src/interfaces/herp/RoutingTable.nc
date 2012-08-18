
 #include <RoutingTable.h>

interface RoutingTable {

    /** Require the next hop for a certain Node.
     *  
     * If the Node is registered into the Routing Table this will trigger
     * the signaling of the deliver() event and the command will return
     * herp_rtres_t::HERP_RT_SUBSCRIBED.
     *
     * If an Entry for the Node is not available, the command will return
     * herp_rtres_t::HERP_RT_REACH.
     *
     * If the Entry for the Node is available, but the information is
     * seasoned, the command will return herp_rtres_t::HERP_RT_VERIFY, and
     * the Out parameter will be assigned with the address of the entry to
     * be verified.
     *
     * If there's no Entry, or the Entry is seasoned, but a process is in
     * charge of inserting/updating it, the command will return
     * herp_rtres_t::HERP_RT_SUBSCRIBED, and the deliver() event will be
     * signaled as the information will be available.
     *
     * @param[in] Node The Node to be searched in the table;
     * @param[out] The Fetched entry (valid only if
     *             herp_rtres_t::HERP_RT_VERIFY is returned).
     *
     *
     * @retval herp_rtres_t::HERP_RT_ERROR On failure;
     * @retval herp_rtres_t::HERP_RT_REACH If there's no Entry;
     * @retval herp_rtres_t::HERP_RT_VERIFY If the Entry needs to be
     *         verified;
     * @retval herp_rtres_t::HERP_RT_SUBSCRIBED On success (the deliver()
     *         event will be eventually triggered).
     */
    command herp_rtres_t get_route (am_addr_t Node, herp_rtentry_t *Out);

    command herp_rtroute_t get_job (herp_rtentry_t Entry);

    command herp_rtres_t drop_job (herp_rtroute_t Route);

    command const herp_rthop_t * get_hop (const herp_rtroute_t Route);

	command herp_rtres_t update_route (herp_rtroute_t Route, const herp_rthop_t *Hop);

    command herp_rtres_t drop_route (herp_rtroute_t Route);

	command herp_rtres_t new_route (am_addr_t Node, const herp_rthop_t *Hop);

    event void deliver (herp_rtres_t Outcome, am_addr_t Node, const herp_rthop_t *Hop);

}
