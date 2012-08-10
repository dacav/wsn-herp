
 #include <HashTable.h>

struct hash_slot {
    void * key;
    void * value;

    hash_slot_t prev, next;
};

generic module HashTableP (typedef key_t, typedef value_t, uint16_t NSLOTS) {

    provides {
        interface Init;
        interface HashTable<key_t, value_t>;
        interface HashItemInit<value_t>;
    }

    uses {
        interface Pool<struct hash_slot> as SlotPool;
        interface Pool<key_t> as KeyPool;
        interface Pool<value_t> as ValuePool;
    }

}

implementation {

    hash_slot_t slots[NSLOTS];
    static hash_slot_t* slot_of (const key_t *Key);

    command error_t Init.init () {
        int i;

        for (i = 0; i < NSLOTS; i ++) {
            slots[i] = NULL;
        }

        return SUCCESS;
    }

    command hash_slot_t HashTable.get (const key_t *Key) {
        hash_slot_t *start;
        hash_slot_t cur, new_slot;
        key_t * new_key;
        value_t * new_value;

        start = slot_of(Key);
        for (cur = *start; cur != NULL; cur = cur->next) {
            if (signal HashTable.key_equal(Key, (const key_t *) cur->key)) {
                return cur;
            }
        }

        new_value = call ValuePool.get();
        if (new_value == NULL) {
            return NULL;
        }
        if (signal HashTable.value_init(Key, new_value) != SUCCESS) {
            call ValuePool.put(new_value);
            return NULL;
        }

        new_key = call KeyPool.get();
        memcpy((void *) new_key, (const void *)Key, sizeof(key_t));

        new_slot = call SlotPool.get();
        new_slot->key = (void *) new_key;
        new_slot->value = (void *) new_value;
        new_slot->next = *start;
        new_slot->prev = NULL;

        if ((cur = *start) != NULL) {
            cur->prev = new_slot;
        }
        *start = new_slot;

        return new_slot;
    }

    command void HashTable.del (hash_slot_t Slot) {
        value_t *value;
        key_t *key;
        hash_slot_t *s;

        if (Slot == NULL) return;

        s = slot_of((const key_t *) Slot->key);
        if (Slot == *s) {
            *s = Slot->next;
            if (Slot->next) Slot->next->prev = NULL;
        } else {
            if (Slot->prev) Slot->prev->next = Slot->next;
            if (Slot->next) Slot->next->prev = Slot->prev;
        }

        key = (key_t *) Slot->key;
        value = (value_t *) Slot->value;
        signal HashTable.value_dispose(key, value);

        call KeyPool.put(key);
        call ValuePool.put(value);
        call SlotPool.put(Slot);
    }

    command value_t * get_item (const key_t *Key) {
        call HashTable.item( call HashTable.get(Key) );
    }

    command void get_del (const key_t *Key) {
        call HashTable.del( call HashTable.get(Key) );
    }

    command value_t * HashTable.item (const hash_slot_t Slot) {
        if (Slot == NULL) return NULL;
        return (value_t *)Slot->value;
    }

    static hash_slot_t *slot_of (const key_t *Key) {
        return &slots[signal HashTable.key_hash(Key) % NSLOTS];
    }

}
