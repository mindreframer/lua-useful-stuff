package = "luma"

version = "scm-1"

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

dependencies = { "lpeg >= 0.7", "cosmo" }

source = {
  url = "git://github.com/mascarenhas/luma.git"
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
