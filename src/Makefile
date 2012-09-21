.PHONY : all tos clean


ifndef TOSROOT
$(error TOSROOT not defined)
endif

CC := c++
CXXFLAGS := -std=c++0x
CPPFLAGS := -I $(TOSROOT)/tos/lib/tossim/
LDFLAGS := -L simbuild/micaz/

all: tos test

test: test.o $(addprefix simbuild/micaz/, tossim.o sim.o c-support.o)

tos:
	$(MAKE) -f Makefile.tinyos micaz sim

clean:
	$(MAKE) -f Makefile.tinyos clean
	rm -f test.o test
