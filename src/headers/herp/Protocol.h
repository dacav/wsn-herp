#ifndef HERP_H
#define HERP_H

 #include <Types.h>

typedef struct {
    herp_opid_t ext_opid;
    am_addr_t from;
    am_addr_t to;
} herp_opinfo_t;

typedef struct {
    am_addr_t prev;
    uint16_t hop_count;
} herp_proto_t;

typedef struct {
    nx_uint8_t *bytes;
    uint16_t len;
} herp_userdata_t;

#endif // HERP_H

