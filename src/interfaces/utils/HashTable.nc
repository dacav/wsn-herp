
 #include <HashTable.h>

interface HashTable <key_type, value_type> {

    command hash_slot_t get (const key_type *Key);

    command void del (hash_slot_t Slot);

    command value_type * item (const hash_slot_t Slot);

    event hash_index_t key_hash (const key_type *Key);

    event bool key_equal (const key_type *Key1, const key_type *Key2);

    event error_t value_init (value_type *val);

    event void value_dispose (value_type *val);

}
