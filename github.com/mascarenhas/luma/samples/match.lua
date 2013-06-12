require"lpeg"
require"luma"
require"leg.scanner"
require"leg.parser"

local re = require"luma.re"

local exp = lpeg.P(leg.parser.apply(lpeg.V"Exp"))
local chunk = lpeg.P(leg.parser.apply(lpeg.V"Chunk"))

local syntax = [[
  match <- _ ('subject' _ {exp} _ clauses clause_else? 'end' _) -> build_match
  clauses <- clause+ -> {}
  captures <- ({name _ (',' _ name _)*} / {""})
  clause <- ('with' _ captures _ '<-' _ {exp} _ 'do' _ {chunk} _ 
    {'fallthrough'?} _) -> build_clause
  clause_else <- ('default' _ {chunk} _) -> build_else
]]

local defs = {
  build_match = function (subj, clauses, clause_else)
    return { subject = subj, clauses = clauses, clause_else = { clause_else },
      re = luma.gensym(), sub = luma.gensym() }
  end,
  build_clause = function (captures, patt, chunk, ft)
    if ft == "fallthrough" then ft = "" else ft = "do break end" end
    if captures == "" then captures = "_" end
    local first_cap = re.match(captures, [[ {[^ ,]+} ]])
    return { captures = captures, pattern = patt, chunk = chunk, 
      fallthrough = ft, first_cap = first_cap }
  end,
  build_else = function (chunk)
    return { chunk = chunk }
  end,
  chunk = chunk,
  exp = exp
}

local code = [[
  do
    local $re = require"re"
    local $sub = $subject
    repeat
    $clauses[=[
      local $captures = $re["match"]($sub, $pattern)
      if $first_cap then
        $chunk
        $fallthrough
      end
    ]=]
    $clause_else[=[
      $chunk
    ]=]
    until true
  end
]]

luma.define("match", syntax, code, defs)
