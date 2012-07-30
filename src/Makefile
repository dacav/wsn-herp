.PHONY : foo

CFLAGS += -I/usr/include/python2.6/
CFLAGS += -Iheaders -Iinterfaces
CFLAGS += $(addprefix -I, $(shell find modules -type d))

LDFLAGS += -Lmodules

CFLAGS += -D_TXOP_PACKED

COMPONENT=HerpAppC
include $(MAKERULES)
