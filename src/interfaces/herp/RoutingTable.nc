
 #include <RoutingTable.h>

interface RoutingTable {

    command herp_rtres_t get_route (am_addr_t Node, herp_rtentry_t *Out);

    command herp_rtroute_t get_job (herp_rtentry_t Entry);

	command herp_rtres_t new_route (am_addr_t Node, const herp_rthop_t *Hop);

	command herp_rtres_t update_route (herp_rtroute_t Route, const herp_rthop_t *Hop);

    command herp_rtres_t drop_route (herp_rtroute_t Route);

    event void deliver (herp_rtres_t Outcome, am_addr_t Node, const herp_rthop_t *Hop);

}
