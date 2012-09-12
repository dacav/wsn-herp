#ifndef HERP_H
#define HERP_H

 #include <Types.h>
 #include <AM.h>
 #include <string.h>

typedef struct {
    herp_opid_t ext_opid;
    am_addr_t from;
    am_addr_t to;
} herp_opinfo_t;

static inline void opinfo_init (herp_opinfo_t *Info,
                                herp_opid_t ext_opid,
                                am_addr_t from,
                                am_addr_t to)
{
    Info->ext_opid = ext_opid;
    Info->from = from;
    Info->to = to;
}

static inline void opinfo_copy (herp_opinfo_t *Dst,
                                const herp_opinfo_t *Src)
{
    memcpy(Dst, Src, sizeof(herp_opinfo_t));
}

#endif // HERP_H

