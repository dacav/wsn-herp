
 #include <FldTable.h>
 #include <AM.h>
 #include <string.h>

generic module FldTableP (typedef entry_data_t, uint16_t N_BUCKETS) {
    provides {
        interface FldTable<entry_data_t>;
        interface Init;
    }
    uses {
        interface Pool<struct fld_entry> as EntryPool;
        interface Pool<entry_data_t> as DataPool;
    }
}

implementation {

    struct fld_entry * buckets[N_BUCKETS];

    command error_t Init.init () {
        int i;

        for (i = 0; i < N_BUCKETS; i ++) {
            buckets[i] = NULL;
        }
        return SUCCESS;
    }

    static bool keys_equal (const fld_key_t *K1, const fld_key_t *K2) {
        return K1->from == K2->from
            && K1->to   == K2->to
            && K1->id   == K2->id;
    }

    command fld_entry_t FldTable.get_entry (const fld_key_t *K) {
        fld_entry_t c, fresh;
        fld_entry_t *head;

        head = &buckets[K->from % N_BUCKETS];
        c = *head;
        while (c != NULL) {
            if (keys_equal(&c->key, K)) {
                return c;
            }
            c = c->next;
        }

        fresh = call EntryPool.get();
        if (fresh != NULL) {
            memcpy((void *)&fresh->key, (const void *)&K,
                   sizeof(fld_key_t));
            fresh->store = (void *) call DataPool.get();
            fresh->next = *head;
            *head = fresh;
        }
        return fresh;
    }

    command void FldTable.free_entry (fld_entry_t E) {
        fld_entry_t *head;

        head = &buckets[E->key.from % N_BUCKETS];
        if (E == *head) {
            *head = (*head)->next;
        } else {
            fld_entry_t c, p;

            c = *head;
            p = NULL;
            while (c != NULL && c != E) { 
                p = c;
                c = c->next;
            }
            p->next = c->next;
        }
        call DataPool.put((entry_data_t *)E->store);
        call EntryPool.put(E);
    }

    command entry_data_t * FldTable.fetch_data (fld_entry_t E) {
        return (entry_data_t *) E->store;
    }

    command fld_key_t * FldTable.fetch_key (fld_entry_t E) {
        return &E->key;
    }

}
