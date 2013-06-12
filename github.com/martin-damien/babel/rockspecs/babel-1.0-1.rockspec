package = "babel"
version = "1.0-1"
source = {
    url = "https://github.com/martin-damien/babel/archive/master.zip"
}
description = {
    summary = "A simple internationalisation module",
    detailed = [[
        A simple internationalisation module to allow Lua developments to be
        multilingual. It also supports LÖVE (https://www.love2d.org/).
    ]],
    homepage = "http://github.com/martin-damien/babel",
    license = "GNU/GPL 3"
}
dependencies = {
    "lua >= 5.1",
    "luafilesystem >= 1.6.0"
}
build = {
    type = "builtin",
    modules = {
        babel = "babel.lua"
    }
}
