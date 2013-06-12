package = "Luma"

version = "0.1-1"

description = {
  summary = "Lpeg-based macro system for Lua",
  detailed = [[
     Luma is a macro system for Lua that allows you to define macros with arbitrary
     syntax, but clearly delimited when surrounded by Lua code. Luma is inspired by
     Scheme's syntax-rules/syntax duo, and uses Lpeg for grammars and Cosmo for
     templates.
  ]],
  license = "MIT/X11",
  homepage = "http://www.lua.inf.puc-rio.br/~mascarenhas/luma"
}

dependencies = { "lpeg >= 0.7" }

source = {
  url = "http://www.lua.inf.puc-rio.br/~mascarenhas/luma/luma-0.1.tar.gz"
}

build = {
   type = "make",
   build_pass = true,
   install_target = "install-rocks",
   install_variables = {
     PREFIX  = "$(PREFIX)",
     LUA_BIN = "/usr/bin/env lua",
     LUA_DIR = "$(LUADIR)",
     BIN_DIR = "$(BINDIR)"
   }
}
