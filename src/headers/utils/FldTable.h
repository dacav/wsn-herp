#ifndef FLD_TABL_H
#define FLD_TABL_H

#include <AM.h>

typedef struct {
    am_addr_t from;
    am_addr_t to;
    uint16_t id;
} fld_key_t;

typedef struct fld_entry {
    fld_key_t key;
    void * store;
    struct fld_entry *next;
} * fld_entry_t;

#endif // FLD_TABL_H
