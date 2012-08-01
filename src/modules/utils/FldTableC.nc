
 #include <FldTable.h>
 #include <AM.h>

generic configuration FldTableC (typedef entry_data_t, uint16_t MAX_SIZE) {
    provides {
        interface FldTable<entry_data_t>;
    }
}

implementation {
    components MainC,
               new FldTableP(entry_data_t, MAX_SIZE / 3),
               new PoolC(struct fld_entry, MAX_SIZE) as EntryPool,
               new PoolC(entry_data_t, MAX_SIZE) as DataPool;

    MainC.SoftwareInit -> FldTableP;
    FldTableP.EntryPool -> EntryPool;
    FldTableP.DataPool -> DataPool;
    FldTable = FldTableP;
}
