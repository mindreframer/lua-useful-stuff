#!/usr/bin/env luma

require_for_syntax[[trycatch]]

local ran_catch = false
local ran_finally = false

try [[
  error("error!")
  assert(false)
catch err
  assert(err)
  ran_catch = true
finally
  ran_finally = true
]]

assert(ran_catch)
assert(ran_finally)

function foo(x)
   ran_catch = false
   ran_finally = false
   try[[
      if x > 2 then
	 return x * 2
      end
      error("invalid")
   catch err
      assert(err)
      ran_catch = true
      return x / 2
   finally
      ran_finally = true
   ]]
end

assert(foo(3) == 6)
assert(not ran_catch)
assert(ran_finally)

assert(foo(1) == 1/2)
assert(ran_catch)
assert(ran_finally)
