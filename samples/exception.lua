#!/usr/bin/env luma

require_for_syntax[[trycatch]]

try [[
  print("Hello world!")
  error("error!")
catch err
  print(err)
--  Reraise
--  error(err)
finally
  print("Finally!")
]]

function foo(x)
   try[[
       if(x > 2) then return x * 2 end
       error("error!")
     catch err
       print(err)
       return x / 2
     finally
       print("in finally")
   ]]
end

print(foo(4))
print(foo(1))
