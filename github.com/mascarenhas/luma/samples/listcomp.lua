require"luma"
require"lpeg"
require"leg.scanner"
require"leg.parser"

local exp = lpeg.P(leg.parser.apply(lpeg.V"Exp"))

local syntax = [[
  comp <- (_ {exp} _ '|'  _ (numfor / genfor) _) -> build_comp
  numfor <-  ({name} _ {~ '<-' -> '=' ~} _ {exp _ ',' _ exp _ (',' _ exp)?}) -> concat
  genfor <- ({name} _ (',' _ name)* _ {~ '<-' -> 'in' ~}  _
    {exp _ (',' _ exp)*}) -> concat
]]

local defs = {
  concat = function (...)
    return table.concat({ ... }, " ")
  end,
  build_comp = function (e, f)
    return { exp = e, exp_for = f, list = luma.gensym() }
  end,
  exp = exp
}

local code = [[
  (function ()
    local $list = {}
    for $exp_for do
      $list[#$list + 1] = $exp
    end
    return $list
  end)()
]]

luma.define("L", syntax, code, defs)

