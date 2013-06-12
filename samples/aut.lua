#!/usr/bin/env luma

require_for_syntax[[automaton]]

local aut = automaton [[
  init: c -> more
  more: a -> more
        d -> more
        ' ' -> more
        r -> finish
  finish: accept
]]

print(aut("cadar"))
print(aut("cad ddar"))
print(aut("caxadr"))

