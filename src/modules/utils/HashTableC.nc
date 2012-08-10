
 #include <HashTable.h>

generic configuration HashTableC (typedef key, typedef value, uint8_t SIZE) {

    provides interface HashTable<key, value>;

}

implementation {

    components MainC;
    components new HashTableP(key, value, SIZE / 3),
               new PoolC(struct hash_slot, SIZE) as SlotPool,
               new PoolC(key, SIZE) as KeyPool,
               new PoolC(value, SIZE) as ValuePool;

    MainC.SoftwareInit -> HashTableP;

    HashTableP.SlotPool -> SlotPool;
    HashTableP.KeyPool -> KeyPool;
    HashTableP.ValuePool -> ValuePool;

    HashTable = HashTableP;

}
