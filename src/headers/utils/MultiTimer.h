#ifndef MULTI_TIMER_H
#define MULTI_TIMER_H

#include <Types.h>

typedef struct sched_item * sched_item_t;

struct sched_item {
    sched_item_t prev, next;
    uint32_t time;
    void * store;
    herp_opid_t id;
    bool active;
};

#endif // MULTI_TIMER_H

