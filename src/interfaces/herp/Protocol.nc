
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

    /** Send a message through the given first hop
     *
     * The message must be pre-initialized with init_user_msg()
     *
     * @param[in] Msg The message to send;
     * @param[in] MsgLen The length of the message;
     * @param[in] FirstHop The first node of the path.
     *
     * @retval The same as AMSend.send() on success;
     * @retval ENOMEM if there are not enough resources to send the message.
     */
    command error_t send_data (message_t *Msg, uint8_t MsgLen,
                               am_addr_t FirstHop);

    /** Initialize user payload message
     *
     * This function must be called on the user message in order to store
     * The HERP protocol information into the internal header.
     *
     * @param[in] Msg The message;
     * @param[in] OpId The operation identifier;
     * @param[in] Target The final destination of the message.
     *
     * @retval SUCCESS on success;
     * @retval FAIL if the message internal size is not enough.
     */
    command error_t init_user_msg (message_t *Msg, herp_opid_t OpId,
                                   am_addr_t Target);

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
