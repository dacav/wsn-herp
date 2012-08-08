
 #include <HashTable.h>

generic component HashTableC (typedef key, typedef value, uint16_t SIZE) {

    provides interface HashTable<key, value>;
    uses {
        interface HashCmp<uint16_t, key>;
        interface ParameterInit<value *> as ValueInit;
        interface ParameterDispose<value *> as ValueDispose;
    }

}

implementation {

    components HashTableP;
    components MainC;
    components new PoolC(struct hash_slot, SIZE) as SlotPool,
               new PoolC(key, SIZE) as KeyPool;
               new PoolC(value, SIZE) as ValuePool;

    MainC.SoftwareInit -> HashTableP;

    HashTableP.HashCmp -> HashCmp;
    HashTableP.SlotPool -> SlotPool;
    HashTableP.KeyPool -> KeyPool;
    HashTableP.ValuePool -> ValuePool;

    HashTable = HashTableP;
    ValueInit = HashTableP;
    ValueDispose = HashTableP;

}
