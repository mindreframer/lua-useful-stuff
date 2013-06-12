require"luma"

local syntax = [[
  using <- _ import+ -> build_using
  module <- {name ('.' name)*} _
  namelist <- ({name} _ (',' _ {name} _)*) -> build_namelist
  import <- ('from' _ module 'import' _ namelist) -> build_import
]]

local defs = {
  build_using = function (...)
    return { imports = {...}, mod = luma.gensym() }
  end,
  build_import = function (module, names)
    return { module = module, names = names }
  end,
  build_namelist = function (...)
    local names = { ... }
    local list = {}
    for i, v in ipairs(names) do
      list[i] = { name = v }
    end
    return list
  end
}

local code = [[
  $imports[=[
    local $mod = require("$module")
    $names[==[
    local $name = $mod["$name"]
    ]==]
  ]=]
]]

luma.define("using", syntax, code, defs)

luma.define_simple("import", function (args)
                                local libname = args[1]
                                local l = require(libname)
                                args.funcs = {}
                                for f, _ in pairs(l) do table.insert(args.funcs, { name = f }) end
                                return [[
                                  local _ = require[=[$1]=]
                                  $funcs[=[
                                  local $name = _[ [==[$name]==] ]
                                  ]=]
                                ]] 
                              end)
