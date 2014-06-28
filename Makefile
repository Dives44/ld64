CC=gcc
CXX=g++
CFLAGS=-O2 -Wall -Iinclude -std=gnu99 -Isrc -Wno-unused-but-set-variable -Wno-unused-function -Wno-unused-variable
CXXFLAGS=
LDFLAGS=
LIBS=-lcrypto

GIT_VERSION=$(shell if ( git tag 2>&1 ) > /dev/null; then git tag | tail -n 1; else echo unknown; fi)
ROOT_DIRECTORY_NAME=$(shell basename $${PWD})

SRC_C_ld64 := arc4random-fbsd.c debugline.c gen_uuid-uuid.c ld_version.c pack-uuid.c strlcpy-fbsd.c unpack-uuid.c
SRC_CXX_ld64 := Options.cpp ld.cpp
SRC_ALL_ld64 := $(SRC_C_ld64) $(SRC_CXX_ld64)
OBJ_ld64 := $(SRC_C_ld64:.c=.o) $(SRC_CXX_ld64:.cpp=.o)

SRC_CXX_rebase := rebase.cpp
SRC_ALL_rebase := $(SRC_CXX_rebase)
OBJ_rebase := $(SRC_CXX_rebase:.cpp=.o)

TARGETS=ld64 rebase

all: $(TARGETS)
.PHONY: all

ld64: $(OBJ_ld64)
	$(CXX) $(LDFLAGS) -o $@ $^ $(LIBS)

rebase: $(OBJ_rebase)
	$(CXX) $(LDFLAGS) -o $@ $^ $(LIBS)

include $(SRC_C_ld64:.c=.d)
include $(SRC_CXX_ld64:.cpp=.d)
include $(SRC_CXX_rebase:.cpp=.d)

%.d: src/%.c
	set -e; rm -f $@; \
	$(CC) -MM -std=gnu99 $(CFLAGS) $< > $@.$$$$; \
	sed 's,\($*\)\.o[ :]*,\1.o $@ : ,g' < $@.$$$$ > $@; \
	rm -f $@.$$$$

%.d: src/%.cpp
	set -e; rm -f $@; \
	$(CXX) -MM $(CFLAGS) $(CXXFLAGS) $< > $@.$$$$; \
	sed 's,\($*\)\.o[ :]*,\1.o $@ : ,g' < $@.$$$$ > $@; \
	rm -f $@.$$$$

%.o : src/%.c
	$(CC) -c -o $@ -std=gnu99 $(CFLAGS) $<

%.o : src/%.cpp
	$(CXX) -c -o $@ $(CFLAGS) $(CXXFLAGS) $<

install :
	install -d $(DESTDIR)/Developer/usr/bin
	install -m 0755 $(TARGETS) $(DESTDIR)/Developer/usr/bin
	ln -sf ld64 $(DESTDIR)/Developer/usr/bin/ld
	ln -sf ld $(DESTDIR)/Developer/usr/bin/i686-apple-darwin9-ld
	ln -sf ld $(DESTDIR)/Developer/usr/bin/powerpc-apple-darwin9-ld

dist : clean
	cd .. && tar cvzf ld64_$(GIT_VERSION).tar.gz --exclude .git $(ROOT_DIRECTORY_NAME)

clean :
	rm -f $(TARGETS)
	rm -f *.o
	rm -f *.d
	rm -f *.d.*
