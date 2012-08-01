.PHONY : foo

CFLAGS += -I/usr/include/python2.6/

CFLAGS += $(addprefix -I, $(shell find interfaces -type d))
CFLAGS += $(addprefix -I, $(shell find headers -type d))
CFLAGS += $(addprefix -I, $(shell find modules -type d))

LDFLAGS += -Lmodules

CFLAGS += -D_TXOP_PACKED

COMPONENT=HerpAppC
include $(MAKERULES)
