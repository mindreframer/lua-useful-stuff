# 
all: soar ldeb1.0.deb

soar: soar.lua ml.lua
	lua soar.lua --static soar.lua

ldeb: ldeb.lua ml.lua
	./soar --static ldeb.lua
	
ldeb1.0.deb: ldeb soar
	./ldeb set name "Steve Donovan"
	./ldeb set email "steve.j.donovan@gmail.com"
	./ldeb  pack -m "ldeb makes Debian packages from Lua scripts" ldeb soar

install: all
	./ldeb install
