#ifndef PROTOCOL_PRIV_H
#define PROTOCOL_PRIV_H

#include <Protocol.h>

/* -- Message Formats ------------------------------------------------ */

/** Type identifiers for messages. */
typedef enum {
    PATH_EXPLORE  = 0x01, /**< Path discovery (broadcasted). */
    PATH_BUILD    = 0x04, /**< Reverse path building. */
    USER_DATA     = 0x08  /**< User payload messages. */
} op_t;

typedef nx_struct {

    /** Operation metadata */
    nx_struct {
        nx_uint8_t type;    /**< Type of operation */
        nx_uint8_t id;      /**< Identifier of the operation */
    } op;

    nx_am_addr_t from;      /**< Source node */
    nx_am_addr_t to;        /**< Destination node */

} header_t;

typedef nx_struct {
    header_t header;     /**< Header of the message */

    /** The union provides different structures, which are supposed to be
     * used dependently on the value of header.op.type */
    nx_union {
        nx_struct {
            nx_uint16_t hop_count;  /**< Incremental with hops; */
            nx_am_addr_t prev;      /**< Previous node */
        } path;
        nx_uint8_t user_payload[0]; /**< Transmission payload */
    } data;

} herp_msg_t;

#endif // PROTOCOL_PRIV_H

