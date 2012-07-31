
 #include <TxTable.h>
 #include <AM.h>

generic module TxTableP (typedef entry_data_t, uint16_t N_BUCKETS) {
    provides {
        interface TxTable<entry_data_t>;
        interface Init;
    }
    uses {
        interface Pool<struct tx_entry> as EntryPool;
        interface Pool<entry_data_t> as DataPool;
    }
}

implementation {

    struct tx_entry * buckets[N_BUCKETS];
    uint16_t next_tx_id;

    command error_t Init.init () {
        int i;

        for (i = 0; i < N_BUCKETS; i ++) {
            buckets[i] = NULL;
        }
        next_tx_id = 0;

        return SUCCESS;
    }

    command tx_entry_t TxTable.new_entry (am_addr_t Addr) {
        tx_entry_t c, fresh;
        tx_entry_t *head;

        if (call EntryPool.empty()) {
            dbg("Out", "Full!!!!\n");
            return NULL;
        }

        head = &buckets[Addr % N_BUCKETS];
        c = *head;
        while (c != NULL) {
            if (c->node == Addr) {
                return NULL;
            }
            c = c->next;
        }

        fresh = call EntryPool.get();

        fresh->node = Addr;
        fresh->tx_id = next_tx_id ++;
        fresh->store = (void *) call DataPool.get();
        fresh->next = *head;

        *head = fresh;

        return fresh;
    }

    command tx_entry_t TxTable.get_entry (am_addr_t Addr, uint16_t Id) {
        tx_entry_t c;

        c = buckets[Addr % N_BUCKETS];
        while (c != NULL) {
            if (c->node != Addr) {
                c = c->next;
            } else if (c->tx_id == Id) {
                return c;
            } else {
                return NULL;
            }
        }

        return NULL;
    }

    command void TxTable.free_entry (tx_entry_t E) {
        tx_entry_t *head;

        head = &buckets[E->node % N_BUCKETS];
        if (E == *head) {
            *head = (*head)->next;
        } else {
            tx_entry_t c, p;

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

    command entry_data_t * TxTable.fetch_data (tx_entry_t E) {
        return (entry_data_t *) E->store;
    }

    command uint16_t TxTable.fetch_id (tx_entry_t E) {
        return E->tx_id;
    }

}
