VERSION = 0.2

PREFIX  = /usr/local
LIBDIR  = $(PREFIX)/lib/lua/5.1
CFLAGS  = -O2 -Wall -fPIC
LDFLAGS = -shared
LDLIBS  = -lmarkdown

SRCROCK = ldiscount-$(VERSION)-1.src.rock
ROCKSPEC= ldiscount-$(VERSION)-1.rockspec

ldiscount.so: ldiscount.o
	$(CC) $(LDFLAGS) $(LDLIBS) -o $@ $<

install: ldiscount.so
	install -Dpm0755 ldiscount.so $(DESTDIR)$(LIBDIR)/ldiscount.so

uninstall:
	rm -f $(DESTDIR)$(LIBDIR)/ldiscount.so

rock: $(SRCROCK)
rockspec: $(ROCKSPEC)

$(SRCROCK): $(ROCKSPEC)
	luarocks pack $(ROCKSPEC)

$(ROCKSPEC): rockspec.in
	@sed 's/@VERSION@/$(VERSION)/g; s/@RELEASE@/1/g' rockspec.in > $@
	@echo 'Generated: $@'

check: ldiscount.so test.lua $(ROCKSPEC)
	@lua test.lua && echo 'Tests passed'
	@luarocks lint $(ROCKSPEC) && echo 'Rockspec file valid'

clean:
	rm -f ldiscount.so ldiscount.o $(SRCROCK) $(ROCKSPEC)


.PHONY: install uninstall rock rockspec check clean
