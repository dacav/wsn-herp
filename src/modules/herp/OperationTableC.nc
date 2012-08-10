
 #include <OperationTable.h>

generic configuration OperationTableC (typedef user_data, uint8_t SIZE) {
    provides interface OperationTable<user_data>;
}

implementation {

    components new OperationTableP(user_data) as OpTabP;

    components
            new PoolC(user_data, SIZE),
            new OperationIdC(SIZE),
            new HashTableC(herp_opid_t, struct herp_oprec, SIZE) as IntMapC,
            new HashTableC(herp_pair_t, herp_opid_t, SIZE) as ExtMapC;

    OpTabP.UserDataPool -> PoolC;
    OpTabP.OperationId -> OperationIdC;
    OpTabP.IntMap -> IntMapC;
    OpTabP.ExtMap -> ExtMapC;

    OperationTable = OpTabP;
}
