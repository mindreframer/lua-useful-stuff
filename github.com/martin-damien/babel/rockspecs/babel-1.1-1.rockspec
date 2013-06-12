package = "babel"
version = "1.1-1"
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

        babel = "babel.lua",

        -- Each local have to be added manualy here
        ["babel-locales.ar-SA"] = "babel-locales/ar-SA.lua",
        ["babel-locales.ca-ES"] = "babel-locales/ca-ES.lua",
        ["babel-locales.cz-CZ"] = "babel-locales/cz-CZ.lua",
        ["babel-locales.da-DK"] = "babel-locales/da-DK.lua",
        ["babel-locales.el-EL"] = "babel-locales/el-EL.lua",
        ["babel-locales.en-AU"] = "babel-locales/en-AU.lua",
        ["babel-locales.en-CA"] = "babel-locales/en-CA.lua",
        ["babel-locales.en-NZ"] = "babel-locales/en-NZ.lua",
        ["babel-locales.en-UK"] = "babel-locales/en-UK.lua",
        ["babel-locales.en-US"] = "babel-locales/en-US.lua",
        ["babel-locales.eo-EO"] = "babel-locales/eo-EO.lua",
        ["babel-locales.es-ES"] = "babel-locales/es-ES.lua",
        ["babel-locales.fr-FR"] = "babel-locales/fr-FR.lua",
        ["babel-locales.hr-HR"] = "babel-locales/hr-HR.lua",
        ["babel-locales.nl-NL"] = "babel-locales/nl-NL.lua",
        ["babel-locales.zh-CN"] = "babel-locales/zh-CN.lua",
        ["babel-locales.zh-HK"] = "babel-locales/zh-HK.lua",
        ["babel-locales.zh-TW"] = "babel-locales/zh-TW.lua",

    },
    copy_directories = { "babel-unit-tests" }
}
