
 #include <Types.h>
 #include <RoutingTableP.h>
 #include <Constants.h>

generic configuration RoutingTableC (uint8_t MAX_OPS, uint8_t MAX_NODES) {

    provides interface RoutingTable;

}

implementation {

    components
        new HashTableC(am_addr_t, struct rt_node, MAX_NODES) as HTab,
        new QueueC(am_addr_t, MAX_OPS),
        new PoolC(struct rt_subscr, MAX_OPS),
        new MultiTimerC(struct rt_entry, HERP_MAX_ROUTES * MAX_OPS);

    components RoutingTableP;

    RoutingTableP.Table -> HTab;
    RoutingTableP.Queue -> QueueC;
    RoutingTableP.SubscrPool -> PoolC;
    RoutingTableP.MultiTimer -> MultiTimerC.MultiTimer[unique("Routing")];

    RoutingTable = RoutingTableP.RTab;

}

