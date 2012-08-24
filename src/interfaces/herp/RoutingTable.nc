
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

    /** Retrieve the job of the given Entry
     *
     * Each entry corresponds to multiple routes. If the get_route()
     * command returned herp_rtres_t::HERP_RT_VERIFY, then it also yielded
     * a Route as output parameter. This function fetches the Entry which
     * requires the job from the route.
     *
     * @param[in] Entry The entry to be searched for job.
     *
     * @retval The pointer to the Entry's internal route.
     * @retval NULL if there's no such job.
     */
    command herp_rtroute_t get_job (herp_rtentry_t Entry);

    /**
     *
     * @retval herp_rtres_t::HERP_RT_SUCCESS on success.
     * @retval herp_rtres_t::HERP_RT_ERROR if the route was not waiting
     *         for a job;
     */
    command herp_rtres_t drop_job (herp_rtroute_t Route);

    /**
     *
     * @param[in] The Route.
     *
     * @retval The Hop stored inside the Route.
     */
    command const herp_rthop_t * get_hop (const herp_rtroute_t Route);

    /**
     *
     * In case of success the caller will be subscribed to the operation
     * (eventually deliver() will be signaled).
     *
     * @retval herp_rtres_t::HERP_RT_SUBSCRIBED on success;
     * @retval herp_rtres_t::HERP_RT_ERROR on failure.
     */
	command herp_rtres_t update_route (herp_rtroute_t Route, const herp_rthop_t *Hop);

    /**
     *
     * @retval herp_rtres_t::SUCCESS on success;
     * @retval herp_rtres_t::HERP_RT_ERROR on failure (the Route was
     *         not owned as job by the caller or invalid).
     */
    command herp_rtres_t drop_route (herp_rtroute_t Route);

    /**
     *
     * In case of success the caller will be subscribed to the operation
     * (eventually deliver() will be signaled).
     *
     * @retval herp_rtres_t::HERP_RT_SUBSCRIBED on success;
     * @retval herp_rtres_t::HERP_RT_ERROR on failure.
     */
	command herp_rtres_t new_route (am_addr_t Node, const herp_rthop_t *Hop);

    /**
     *
     * @param[in] Outcome herp_rtres_t::HERP_RT_SUCCESS or
     *            herp_rtres_t::HERP_RT_RETRY.
     */
    event void deliver (herp_rtres_t Outcome, am_addr_t Node, const herp_rthop_t *Hop);

}
