#ifndef HERP_H
#define HERP_H

/** ID for Active Message */
enum {
    HERP_MSG = 6
};

/* -- Message Formats ------------------------------------------------ */

/** Type identifiers for messages. */
typedef enum {
    HERP_TYPE_REACH  = 0x01,  /**< Path discovery (broadcasted). */
    HERP_TYPE_PATH_B = 0x02,  /**< Reverse path building. */
    HERP_TYPE_PATH_V = 0x04,  /**< Forward path verification. */
    HERP_TYPE_MSG    = 0x08   /**< User payload messages. */
} herp_type_t;

typedef nx_struct {
    nx_uint8_t type;
    nx_uint8_t id;
    nx_am_addr_t from;
    nx_am_addr_t to;
} herp_head_t;

typedef nx_struct {

    herp_head_t header;

    nx_union {

        /** To be used when nx_struct::type is
         * herp_type_t::HERP_TYPE_REACH. */
        nx_struct {
            nx_uint16_t hop_count;  /**< Hops to source. */
            nx_uint16_t max_hop;    /**< Max distance in hops. */
            nx_am_addr_t previous;  /**< Previous hop. */
        } reach;

        /** To be used when nx_struct::type is
         * herp_type_t::HERP_TYPE_PATH_B or
         * herp_type_t::HERP_TYPE_PATH_V. */
        nx_struct {
            nx_am_addr_t hops[0];
        } path;

        /** To be used when nx_struct::type is
         * herp_type_t::HERP_TYPE_MSG */
        nx_struct {
            nx_uint8_t user_payload[0];
        } msg;

    };

} herp_msg_t;

#endif // HERP_H

