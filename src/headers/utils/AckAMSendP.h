#ifndef ACK_AMSEND
#define ACK_AMSEND

typedef struct {
    uint8_t retry    : 6;
    uint8_t fresh    : 1;
    uint8_t to_check : 1;
} send_info_t;

#endif // ACK_AMSEND

