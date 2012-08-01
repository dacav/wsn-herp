
 #include <TxTable.h>
 #include <AM.h>

generic configuration TxTableC (typedef entry_data_t, uint16_t MAX_SIZE) {
    provides interface TxTable<entry_data_t>;
    uses interface InitItem<entry_data_t>;
}

implementation {
    components MainC,
               new TxTableP(entry_data_t, MAX_SIZE / 3),
               new PoolC(struct tx_entry, MAX_SIZE) as EntryPool,
               new PoolC(entry_data_t, MAX_SIZE) as DataPool;

    MainC.SoftwareInit -> TxTableP;
    TxTableP.EntryPool -> EntryPool;
    TxTableP.DataPool -> DataPool;

    TxTable = TxTableP;
    TxTableP = InitItem;
}
