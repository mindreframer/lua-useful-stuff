#!/usr/bin/env luma

require_for_syntax[[block_func]]

map = block_func [[ (tab, block)
  local list = {}
  for _, v in ipairs(tab) do
    list[#list + 1] = block(v)
  end
  return list
]]

each = block_func [[ (tab, block)
  for _, v in ipairs(tab) do block(v) end
]]

l = map{ 1, 2, 3 } with [[ (x)
  return x * 2
]]

each(l) with [[ (x)
  print(x)
]]
