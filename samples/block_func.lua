require"lpeg"
require"luma"
require"leg.parser"

local block = lpeg.P(leg.parser.apply(lpeg.V"Block"))

local syntax = [[
  funcbody <- ( _ args _ body _ ) -> build_funcbody
  args <- '(' _ namelist _ ')'
  namelist <- ( {name} _ (',' _ {name})* / '' ) -> build_list
  body <- {block}
]]

local common_defs = {
  build_list = function (...)
    return {...}
  end,
  block = block
}

local with_defs = {
  build_funcbody = function (args, body)
    return { args = table.concat(args, ","),  body = body }
  end
}

setmetatable(with_defs, { __index = common_defs })

local block_func_defs = {
  build_funcbody = function (args, body)
    local block = args[#args]
    if not block then error("block function must have a block argument") end
    args[#args] = nil
    return { block = block, args = table.concat(args,""), body = body }
  end
}

setmetatable(block_func_defs, { __index = common_defs })

with_code = [[(function ($args)
  $body
end)]]

block_func_code = [[function ($args)
  return function ($block)
    $body
  end
end]]

luma.define("with", syntax, with_code, with_defs)
luma.define("block_func", syntax, block_func_code, block_func_defs)
