 #include <AM.h>

generic configuration TxOpsC (typedef val_t, uint16_t MAX_SIZE) {
    provides {
        interface TxOps<am_addr_t, val_t> as TxOps;
    }
}

implementation {
    components MainC,
               new TxOpsP(val_t, MAX_SIZE),
               new BitVectorC(MAX_SIZE);

    MainC.SoftwareInit -> BitVectorC;
    MainC.SoftwareInit -> TxOpsP;

    TxOpsP.SlotUsed -> BitVectorC.BitVector;
    TxOps = TxOpsP;
}
