
 #include <TinyError.h>
 #include <Types.h>
 #include <RoutingTable.h>
 #include <Protocol.h>

interface Protocol {

    command error_t send_reach (herp_opid_t OpId, am_addr_t Target);

    command error_t send_verify (herp_opid_t OpId, am_addr_t Target,
                                 am_addr_t FirstHop);

    command error_t send_build (herp_opid_t OpId, const herp_opinfo_t *Info,
                                am_addr_t BackHop);

    command error_t send_data (herp_opid_t OpId, am_addr_t Target,
                               am_addr_t FirstHop, message_t *Msg,
                               uint8_t MsgLen);

    event void done(herp_opid_t OpId, error_t E);

    /**
     *
     * @retval NULL for <i>don't forward</i>;
     * @retval AM_BROADCAST_ADDR for <i>forward broadcast</i>;
     * @retval AM_BROADCAST_ADDR for <i>forward to a specific node</i>.
     */
    event const am_addr_t * got_explore (const herp_opinfo_t *Info,
                                         const herp_proto_t *Data);
    /**
     *
     * @retval NULL for <i>don't forward</i>;
     * @retval an address for forwarding
     */
    event const am_addr_t * got_build (const herp_opinfo_t *Info,
                                       const herp_proto_t *Data);
    /**
     *
     * @retval The next hop if the message is not for the current node;
     * @retval NULL if the message must not be propagated.
     */
    event const am_addr_t * got_payload (const herp_opinfo_t *Info,
                                         const herp_userdata_t *Data);

}
