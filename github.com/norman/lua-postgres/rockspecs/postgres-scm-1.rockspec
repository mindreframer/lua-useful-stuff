package = "postgres"
version = "scm-1"

source = {
  url = "git://github.com/norman/lua-postgres.git"
}

description = {
  summary  = "A Postgres library for Lua",
  detailed = "A PostgreSQL driver for Lua.",
  license  = "MIT/X11",
  homepage = "http://norman.github.com/lua-postgres"
}

dependencies = {
  "lua >= 5.1"
}

build = {
  type = "make"
}
