
 #include <Types.h>
 #include <RoutingTableP.h>
 #include <Constants.h>

generic configuration RoutingTableC (uint8_t MAX_OPS, uint8_t MAX_NODES) {

    provides interface RoutingTable[herp_opid_t];

}

implementation {

    components
        new HashTableC(am_addr_t, struct routes, MAX_NODES) as HTab,
        new QueueC(deliver_t, MAX_OPS),
        new PoolC(struct subscr_item, MAX_OPS),
        new MultiTimerC(struct herp_rtentry, HERP_MAX_ROUTES * MAX_OPS);

    components RoutingTableP;

    RoutingTableP.Table -> HTab;
    RoutingTableP.Delivers -> QueueC;
    RoutingTableP.SubscrPool -> PoolC;
    RoutingTableP.MultiTimer -> MultiTimerC.MultiTimer[unique("Routing")];

    RoutingTable = RoutingTableP.RTab;

}

