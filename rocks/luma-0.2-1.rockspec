package = "luma"

version = "0.2-1"

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

dependencies = { "lpeg >= 0.10", "cosmo" }

source = {
  url = "http://cloud.github.com/downloads/mascarenhas/luma/luma-0.2.tar.gz"
}

build = {
   type = "builtin",
   modules = {
     luma = "src/luma.lua",
     ["luma.re"] = "src/re.lua"
   },
   install = {
     bin = { "bin/luma", "bin/luma-expand" }
   },
   copy_directories = { "doc", "samples", "tests" }
}
