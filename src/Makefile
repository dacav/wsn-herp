.PHONY : foo

CFLAGS += -I/usr/include/python2.6/
CFLAGS += $(addprefix -I, headers interfaces modules)

LDFLAGS += -Lmodules

CFLAGS += -D_TXOP_PACKED

COMPONENT=HerpAppC
include $(MAKERULES)
