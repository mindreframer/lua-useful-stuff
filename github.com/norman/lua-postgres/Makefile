.PHONY: test spec

LUA_VERSION  = $(shell lua -e 'print(_VERSION:sub(5,7))')
LUA_DIR      = /usr/local
LUA_LIBDIR   = $(LUA_DIR)/lib/lua/$(LUA_VERSION)
LUA_SHAREDIR = $(LUA_DIR)/share/lua/$(LUA_VERSION)

PG_LIBDIR    = $(shell pg_config --libdir)
PG_INCDIR    = $(shell pg_config --includedir)

LIBFLAG      = -Wall -shared -fpic

CC=cc

postgres/core.so: src/*.c
	@-mkdir -p postgres
	$(CC) -o postgres/core.so $(ARCHFLAGS) $(LIBFLAG) $(CFLAGS) src/*.c -L$(LUA_LIBDIR) -llua -I$(PG_INCDIR) -L$(PG_LIBDIR) -lpq

clean:
	rm -r postgres

test: postgres/core.so
	@-tsc test/test.lua

spec: postgres/core.so
	@-tsc -f test/test.lua

install: postgres/core.so
	mkdir -p $(LUA_LIBDIR)/postgres
	mkdir -p $(LUA_SHAREDIR)/postgres
	cp  postgres/core.so $(LUA_LIBDIR)/postgres/core.so
	cp  -r src/postgres/ext $(LUA_SHAREDIR)/postgres
	cp  -r src/postgres.lua $(LUA_SHAREDIR)/postgres.lua

uninstall:
	-rm    $(LUA_LIBDIR)/postgres/core.so
	-rmdir $(LUA_LIBDIR)/postgres
	-rm    $(LUA_SHAREDIR)/postgres.lua
	-rm    $(LUA_SHAREDIR)/postgres/ext/connection.lua
	-rmdir $(LUA_SHAREDIR)/postgres/ext
	-rmdir $(LUA_SHAREDIR)/postgres

rock:
	luarocks make rockspecs/postgres-scm-1.rockspec

memtest: clean postgres/core.so
	@valgrind --leak-check=full lua test/memtest.lua

doc:
	ldoc.lua -f markdown src/
