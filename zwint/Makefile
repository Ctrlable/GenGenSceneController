
SRCNAME = zwint.c
OBJNAME = zwint.o
LIBNAME = zwint.so

CWD = $(shell pwd)
BASE_DIR = $(realpath $(CWD)/../OpenWrt-SDK-ramips-for-linux-i486-gcc-4.6-linaro_uClibc-0.9.33.2)
STAGING_DIR = $(BASE_DIR)/staging_dir
TOOLCHAIN = $(STAGING_DIR)/toolchain-mipsel_r2_gcc-4.6-linaro_uClibc-0.9.33.2
CC = $(TOOLCHAIN)/bin/mipsel-openwrt-linux-gcc
STRIP = $(TOOLCHAIN)/bin/mipsel-openwrt-linux-strip
CFLAGS = -I$(STAGING_DIR)/target-mipsel_r2_uClibc-0.9.33.2/usr/include -fPIC -Os -Wall -mips16 -march='mips32r2'
LFLAGS = -pthread -shared -z relro
INSTALL_PATH = $(CWD)

export STAGING_DIR

all: $(LIBNAME)

$(OBJNAME): $(SRCNAME)
	$(CC) -o $(OBJNAME) -c $(SRCNAME) $(CFLAGS)

$(LIBNAME): $(OBJNAME)
	$(CC) -o $(LIBNAME) -shared $(OBJNAME) $(LFLAGS)
	$(STRIP) $(LIBNAME)

install: $(LIBNAME)
	install -D -s $(LIBNAME) $(DESTDIR)$(INSTALL_PATH)/$(LIBNAME)

clean:
	$(RM) $(LIBNAME) $(OBJNAME)


.PHONY: all install clean
