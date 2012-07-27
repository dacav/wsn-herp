 #include <AM.h>
 #include "TxOps.h"

struct slot {
    void * store;
    am_addr_t id;
}
#ifdef _TXOP_PACKED
__attribute__((packed))
#endif
;

typedef enum {
    FOUND,
    FULL,
    ALLOCATE
} seek_res_t;

generic module TxOpsP (typedef val_t, uint16_t MAX_SIZE) {
    provides {
        interface TxOps<am_addr_t, val_t>;
        interface Init;
    }
    uses {
        interface BitVector as SlotUsed;
    }
}

implementation {

    struct slot slots[MAX_SIZE * 2];
    unsigned n_stored;

    command error_t Init.init () {
        n_stored = 0;
        return SUCCESS;
    }

    seek_res_t seek (am_addr_t Id, uint16_t *Res, bool Limit) {

        unsigned i, start, first_unused;
        unsigned back_count;

        start = (Id % MAX_SIZE) * 2;
        first_unused = -1;
        back_count = Limit ? n_stored : (MAX_SIZE * 2);

        for (i = 0; back_count > 0 && i < (MAX_SIZE * 2); i ++) {
            uint16_t j = (start + i) % (MAX_SIZE * 2);

            dbg("Out", "Trying with pos=%d\n", j);
            if (call SlotUsed.get(j)) {
                back_count --;
                if (slots[j].id == Id) {
                    *Res = j;
                    dbg("Out", "Found in %d steps (pos=%d)\n", i, j);
                    return FOUND;
                }
            } else if (first_unused == -1) {
                first_unused = j;
            }
        }

        if (first_unused == -1) {
            return FULL;
        }

        *Res = first_unused;
        dbg("Out", "First unused (pos=%d)\n", first_unused);
        return ALLOCATE;
    }

    command slot_t TxOps.acquire (am_addr_t Id) {
        uint16_t pos;

        switch (seek(Id, &pos, FALSE)) {
            case ALLOCATE:
                slots[pos].id = Id;
                call SlotUsed.set(pos);
                n_stored ++;
                dbg("Out", "Not found but Allocated\n");
            case FOUND:
                return &slots[pos];
            default:
                return NULL;
        }
    }

    command slot_t TxOps.retrieve (am_addr_t Id) {
        uint16_t pos;

        switch (seek(Id, &pos, TRUE)) {
            case ALLOCATE:
            case FULL:
                /* Must exist and be allocated already! */
                return NULL;
            default:
                return &slots[pos];
        }
    }

    command val_t * TxOps.access (slot_t S) {
        return (val_t *) &S->store;
    }

    command void TxOps.drop (slot_t S) {
        uintptr_t offset = ((uintptr_t)S - (uintptr_t)slots);
        uint16_t pos = (uint16_t)(offset / sizeof(void *));

        dbg("Out", "Dropping %d\n", pos);
        call SlotUsed.clear(pos);
        n_stored --;
    }

}
