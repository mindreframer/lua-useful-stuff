#!/usr/bin/env luma

meta [[

local function fact(n)
  n = tonumber(n)
  local a = 1
  for i = 2, n do
    a = a * i
  end
  return a
end

luma.define_simple("fact", function (args)
                              return fact(args[1])
                            end)
]]

print(fact [[ 3 ]])

