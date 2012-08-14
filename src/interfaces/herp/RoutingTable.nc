
 #include <RoutingTable.h>

interface RoutingTable {

    command herp_rtres_t get_route (am_addr_t Node, herp_rtentry_t *Out);

    command const herp_rthop_t * get_hop (const herp_rtentry_t Entry);

    command herp_rtres_t flag_working (herp_rtentry_t Entry);

    /** Simply add a route
     *
     * @param Node
     * @param Hop
     *
     * @retval
     */
	command herp_rtres_t add_route (am_addr_t Node, const herp_rthop_t *Hop);

	command herp_rtres_t refresh_route (herp_rtentry_t Entry, const herp_rthop_t *Hop);

    /** Drop a route, fetch another.
     *
     * The calling code drops a route using this call (the route is passed
     * as parameter. Then the parameter may be filled with another route
     * to the same Node, and the behavior is the same as in get_route().
     *
     * @param[in] Node The target node of the route;
     * @param[in,out] Hop The hop pointer.
     *
     * @return Same as get_route().
     */
    command herp_rtres_t drop_route (herp_rtentry_t *Entry);

    event void deliver (herp_rtres_t Outcome, am_addr_t Node, const herp_rthop_t *Hop);

}
