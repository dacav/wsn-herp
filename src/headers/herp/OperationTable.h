#ifndef OPERATION_TABLE_H
#define OPERATION_TABLE_H

#include <Types.h>
#include <AM.h>

typedef struct herp_oprec * herp_oprec_t;

/** Operation table record */
struct herp_oprec {

    /** Identifiers of the operation */
    struct {
        herp_opid_t internal;   /**< Internal (local node); */
        herp_opid_t external;   /**< External (Internal for remote node); */
    } ids;

    am_addr_t owner;           /**< Owner node for the operation. */

    struct {
        herp_oprec_t prev;     /**< Prev in list; */
        herp_oprec_t next;     /**< Next in list. */
    } subscr;

    void * store;               /**< User data pointer */

};

typedef struct {
    am_addr_t node;
    herp_opid_t ext_id;
} herp_pair_t;

#endif // OPERATION_TABLE_H
