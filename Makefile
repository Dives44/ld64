CC=gcc
CXX=g++
CFLAGS=-Werror -Wall -Iinclude -Isrc -D_LARGEFILE64_SOURCE -DEMULATED_HOST_CPU_TYPE=CPU_TYPE_I386 -DEMULATED_HOST_CPU_SUBTYPE='CPU_SUBTYPE_INTEL(12, 1)' -Wno-unused-but-set-variable -Wno-unused-function -Wno-unused-variable
CXXFLAGS=
LDFLAGS=
LIBS=-lcrypto

GIT_VERSION=$(shell if ( git tag 2>&1 ) > /dev/null; then git tag | tail -n 1; else echo unknown; fi)
ROOT_DIRECTORY_NAME=$(shell basename $${PWD})

SRC_C_common := SymLoc.c allocate.c apple_version.c arch.c arch_usage.c best_arch.c breakout.c bytesex.c checkout.c coff_bytesex.c crc32.c dylib_roots.c dylib_table.c emulated.c errors.c execute.c fatal_arch.c fatals.c get_arch_from_host.c get_toc_byte_sex.c guess_short_name.c hash_string.c hppa.c lto.c macosx_deployment_target.c ofile.c ofile_error.c ofile_get_word.c print.c reloc.c round.c seg_addr_table.c set_arch_flag_name.c swap_headers.c symbol_list.c unix_standard_mode.c version_number.c vm_flush_cache.c writeout.c

SRC_C_ld64 := arc4random-fbsd.c debugline.c gen_uuid-uuid.c ld_version.c pack-uuid.c strlcpy-fbsd.c unpack-uuid.c $(SRC_C_common)
SRC_CXX_ld64 := Options.cpp ld.cpp
SRC_ALL_ld64 := $(SRC_C_ld64) $(SRC_CXX_ld64)
OBJ_ld64 := $(SRC_C_ld64:.c=.o) $(SRC_CXX_ld64:.cpp=.o)

SRC_C_rebase := $(SRC_C_common)
SRC_CXX_rebase := rebase.cpp
SRC_ALL_rebase := $(SRC_C_rebase) $(SRC_CXX_rebase)
OBJ_rebase := $(SRC_C_rebase:.c=.o) $(SRC_CXX_rebase:.cpp=.o)

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
