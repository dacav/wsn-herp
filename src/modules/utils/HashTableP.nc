
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
    }

    uses {
        interface HashCmp<uint16_t, key_t>;

        interface Pool<struct hash_slot> SlotPool;
        interface Pool<key_t> KeyPool;
        interface Pool<value_t> ValuePool;

        interface ParameterInit<value_t *> as ValueInit;
        interface ParameterDispose<value_t *> as ValueDispose;
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
        hash_slot_t cur, prev, new_slot;
        key_t * new_key;
        value_t * new_value;

        if (call SlotPool.empty()) {
            return NULL;
        }

        found = FALSE;
        start = slot_of(Key);

        for (cur = *start; cur != NULL; cur = cur->next) {
            if (call HashCmp.equal(Key, (const key_t *) cur->key)) {
                return cur;
            }
        }

        new_value = call ValuePool.get();
        if (call ValueInit.init(new_value) != SUCCESS) {
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
        hash_slot_t *s;

        s = slot_of((const key_t *) Slot->key)
        if (Slot == s) {
            *s = slot->next;
            if (slot->next) slot->next->prev = NULL;
        } else {
            if (slot->prev) slot->prev->next = slot->next;
            if (slot->next) slot->next->prev = slot->prev;
        }

        value = (value_t *) Slot->value;
        call ValueDispose.dispose(value);
        call ValuePool.put(value);

        call KeyPool.put((key_t *)Slot->key);

        call SlotPool.put(Slot);
    }

    value_t * HashTable.item (const hash_slot_t Slot) {
        return (value_t *)Slot->value;
    }

    static hash_slot_t *slot_of (const key_t *Key) {
        return &slots[call HashCmp.hash(Key) % NSLOTS];
    }

}
