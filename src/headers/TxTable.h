#ifndef TX_TABLE_H
#define TX_TABLE_H

 #include <AM.h>

typedef struct tx_entry {
    am_addr_t node;
    uint16_t tx_id;
    void *store;
    struct tx_entry *next;
} * tx_entry_t;

#endif // TX_TABLE_H

