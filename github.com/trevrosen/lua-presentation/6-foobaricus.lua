-- In Lua, we can act on an object defined in another context,
-- because everything is global by default.

-- Start an interactive Lua session in this directory and input the following:
-- dofile('foobaricus.lua')

-- unless the expression is true, an error is raised
assert(foobaricus, "you must have a 'foobaricus' table in your environment")

foobaricus.fun() -- will throw error unless foobaricus.fun has been defined

foobaricus.zanzibar = function (name)
  print(string.format("We are taking %s to Zanzibar", name))
end


