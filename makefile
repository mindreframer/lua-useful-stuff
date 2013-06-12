# $Id: Makefile,v 1.1.1.1 2007/11/26 17:12:24 mascarenhas Exp $

config_file:=config

ifneq '$(wildcard $(config_file))' ''
include $(config_file)
endif

$(config_file):
	chmod +x configure

install: $(config_file)
	sed -e '1s,^#!.*,#!$(LUA_BIN),' bin/luma > $(BIN_DIR)/luma
	chmod +x $(BIN_DIR)/luma
	sed -e '1s,^#!.*,#!$(LUA_BIN),' bin/luma-expand > $(BIN_DIR)/luma-expand
	chmod +x $(BIN_DIR)/luma-expand
	mkdir -p $(LUA_DIR)
	mkdir -p $(LUA_DIR)/luma
	cp src/luma.lua $(LUA_DIR)
	cp src/re.lua $(LUA_DIR)/luma
	grep -l "^#!" samples/*.lua | xargs chmod +x

test:
	cd tests && luma test.lua

paper:
	cd doc/paper && pandoc -f markdown -t latex -B luma-paper-header.tex \
	   -A luma-paper-footer.tex luma-paper.pdc \
           | utf8tolatin1 > luma-paper.tex

clean:
