
 #include <TinyError.h>
 #include <Types.h>
 #include <RoutingTable.h>
 #include <Protocol.h>

interface Protocol {

    command error_t send_reach (herp_opid_t OpId, am_addr_t Target);

    command error_t send_data (herp_opid_t OpId, am_addr_t Target,
                               am_addr_t FirstHop, message_t *Msg,
                               uint8_t MsgSize);

    event void done(herp_opid_t OpId, error_t E);

    event void got_explore (const herp_opinfo_t *Info,
                            const herp_proto_t *Data);

    event void got_build (const herp_opinfo_t *Info,
                          const herp_proto_t *Data);

    event void got_payload (const herp_opinfo_t *Info,
                            const herp_userdata_t *Data);

}
