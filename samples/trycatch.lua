require"lpeg"
require"luma"
require"leg.parser"

local chunk = lpeg.P(leg.parser.apply(lpeg.V"Chunk"))

local syntax = [[
    try <- _ ({chunk} _ catch? finally?) -> build_try 'end'? _
    catch <- 'catch' _ ({name} _ {chunk} _) -> build_catch
    finally <- 'finally' _ {chunk} -> build_finally _
]]

local defs = {
  build_catch = function (var, chunk)
    return { var = var, chunk = chunk }
  end,
  build_finally = function (chunk)
    return { chunk = chunk }
  end,
  build_try = function (chunk, tf1, tf2)
    local try = { chunk = chunk, catch = {}, finally = "",
     falloff = luma.gensym(), values = luma.gensym()  }
    if tf1.var then
      try.catch = { tf1 }
      if tf2 then try.finally = tf2.chunk end
    elseif tf1 then
      try.finally = tf1.chunk
    end
    return try
  end,
  chunk = chunk
}

local code = [[
  do
     local $falloff = {}
     local $values = { pcall(function () 
				do
				   $chunk
				end
				return $falloff
			     end) }
     if $values[1] then
	$finally
	if $values[2] ~= $falloff then
	   return unpack($values, 2)
	end
     else
	$catch[=[
        $values = { pcall(function ($var) 
			     do
				$chunk
			     end
			     return $falloff
			  end, $values[2]) }
        ]=]
        $finally
        if not $values[1] then error($values[2]) end
	if $values[2] ~= $falloff then
	   return unpack($values, 2)
	end
     end
  end
]]

luma.define("try", syntax, code, defs)
