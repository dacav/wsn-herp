generic configuration OperationIdC (uint16_t SIZE) {

    provides interface OperationId;

}

implementation {

    components MainC,
            new OperationIdP(SIZE),
            new BitVectorC(SIZE);

    MainC.SoftwareInit -> OperationIdP.Init;
    OperationIdP.InitBitVector -> BitVectorC.Init;
    OperationIdP.Free -> BitVectorC;

    OperationId = OperationIdP;

}
