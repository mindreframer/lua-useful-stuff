#!/usr/bin/env luma

meta [[

luma.define_simple("nor", "not ($args[[($value) or ]] false)")

]]

a, b, c, d = false, true, false, true

assert(nor[[a == b, b == a and c == d, c]])
assert(not nor[[a, b, c, d]])


