#ifndef HERP_H
#define HERP_H

 #include <Types.h>
 #include <AM.h>

typedef struct {
    herp_opid_t ext_opid;
    am_addr_t from;
    am_addr_t to;
} herp_opinfo_t;

#endif // HERP_H

