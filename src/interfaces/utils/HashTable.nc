interface HashTable <key_type, data_type> {

    hash_slot_t get (const key_type Key);

    void del (hash_slot_t Slot);

    data_type * item (const hash_slot_t Slot);

}
