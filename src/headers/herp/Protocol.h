#ifndef HERP_H
#define HERP_H

 #include <Types.h>
 #include <AM.h>

typedef struct {
    herp_opid_t ext_opid;
    am_addr_t from;
    am_addr_t to;
} herp_opinfo_t;

typedef struct {
    am_addr_t node;
    uint16_t hop_count;
} herp_proto_t;

typedef struct {
    message_t *msg;
    uint8_t len;
} herp_userdata_t;

#endif // HERP_H

