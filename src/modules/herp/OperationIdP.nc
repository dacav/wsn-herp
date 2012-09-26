
 #include <Types.h>
 #include <assert.h>
 #include <TinyError.h>

typedef struct {
    uint16_t next;
    uint16_t prev;
} opid_slot_t;

generic module OperationIdP (uint16_t SIZE) {

    provides {
        interface Init;
        interface OperationId;
    }

    uses {
        interface BitVector as Free;
        interface Init as InitBitVector;
    }

}

implementation {

    opid_slot_t slots[SIZE];
    uint16_t available;
    uint16_t first_free;

    command error_t Init.init () {
        error_t ret;
        int i;

        assert(SIZE > 0);

        for (i = 0; i < SIZE; i ++) {
            slots[i].next = i + 1;
            slots[i].prev = i - 1;
        }

        slots[0].prev = SIZE - 1;
        slots[SIZE - 1].next = 0;

        available = SIZE;

        ret = call InitBitVector.init();
        if (ret == SUCCESS) {
            call Free.setAll();
            first_free = 0;
        }
        return ret;
    }

    command error_t OperationId.get (herp_opid_t * Id) {
        uint16_t p, n;

        if (!available) {
#ifdef DUMP
            dbg("OpId", "!!! Out of opids !!!");
#endif
            return EBUSY;
        }

        p = slots[first_free].prev;
        n = slots[first_free].next;

        slots[p].next = n;
        slots[n].prev = p;
        available --;
        call Free.toggle(first_free);
        *Id = first_free;
        first_free = n;

#ifdef DUMP
        dbg("OpId", "%d in use\n", *Id);
#endif

        return SUCCESS;
    }

    command error_t OperationId.put (herp_opid_t Id) {
        if (Id >= SIZE) return EINVAL;
        if (call Free.get(Id)) {
#ifdef DUMP
            dbg("OpId", "Double free!\n");
#endif
            return EALREADY;
        }

        if (available) {
            slots[Id].next = slots[first_free].next;
            slots[Id].prev = first_free;
            slots[first_free].next = Id;
        } else {
            slots[Id].next = Id;
            slots[Id].prev = Id;
        }

        call Free.toggle(Id);
        first_free = Id;
        available ++;

#ifdef DUMP
        dbg("OpId", "%d free!\n", Id);
#endif

        return SUCCESS;
    }

}
