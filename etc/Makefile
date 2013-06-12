CC = gcc
CFLAGS = -Wall -O2

# Linux
INCFLAGS = -I/usr/include/lua5.1
LUALIB = /usr/lib/liblua5.1.a
LUACFLAGS = -DLUA_USE_LINUX
BINFLAGS = 
LIBS = -lm -Wl,-E -ldl -lreadline -lhistory -lncurses
# MacOSX
#INCFLAGS = -I/sw/include
#LUALIB = /sw/lib/liblua.a
#LUACFLAGS = -DLUA_USE_LINUX
#BINFLAGS = 
#LIBS = -lm -lreadline
# MinGW
#INCFLAGS = -I/usr/local/include
#LUALIB = /usr/local/lib/lua51.dll
#LUACFLAGS = -DLUA_BUILD_AS_DLL
#BINFLAGS = -s
#LIBS = -lm

RM = rm -f
LUAC = luac
HEX = xxd -i

LIBOBJS = rng.o ranlib.o mt.o cdf.o dcdflib.o ipmpar.o \
			 binomial.o queue.o stack.o
OBJS = slinit.o simulua.o

BIN = simulua
LUA = ../simulua.lua
LC = simulua.lc
INC = simulua_lc.h

all : $(BIN)

$(BIN) : $(OBJS) $(LIBOBJS)
	$(CC) $(BINFLAGS) -o $@ $^ $(LUALIB) $(LIBS)

$(INC) : $(LC)
	$(HEX) $< > $@

$(LC) : $(LUA)
	$(LUAC) -o $@ $<

$(LIBOBJS) : %.o : ../lib/%.c
	$(CC) $(CFLAGS) $(LUACFLAGS) $(INCFLAGS) -c -o $@ $<

$(OBJS) : %.o : %.c
	$(CC) $(CFLAGS) $(LUACFLAGS) $(INCFLAGS) -c -o $@ $<

clean :
	$(RM) $(LIBOBJS) $(OBJS) $(BIN)
