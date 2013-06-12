require"luma"

local syntax = [==[
  aut <- _ state+ -> build_aut
  char <- ([']{[ ]}['] / {.}) _
  rule <- (char '->' _ {name} _) -> build_rule 
  state <- ( {name} _ ':' _ rule* -> {} {'accept'?} _ ) -> build_state
]==]

local defs = {
  build_rule = function (c, n)
    return { char = c, next = n }
  end,
  build_state = function (n, rs, accept)
    local final = tostring(accept == 'accept')
    return { name = n, rules = rs, final = final }
  end,
  build_aut = function (...)
    return { init = (...).name, states = { ... }, 
      substr = luma.gensym(), c = luma.gensym(),
      input = luma.gensym(), rest = luma.gensym() }
  end
}

local code = [[
  (function ($input)
    local $substr = string.sub
    $states[=[
      local $name
    ]=]
    $states[=[
      $name = function ($rest)
        if #$rest == 0 then
          return $final
        end
        local $c = $substr($rest, 1, 1)
        $rest = $substr($rest, 2, #$rest)
        $rules[==[
          if $c == '$char' then
            return $next($rest)
          end
        ]==]
        return false
      end
    ]=]
    return $init($input)
  end)]]

luma.define("automaton", syntax, code, defs) 


