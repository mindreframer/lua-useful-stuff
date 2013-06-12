#!/usr/bin/env luma

meta [[

luma.define_simple("nor", "not ($args[[($value) or ]] false)")

]]

a, b, c, d = false, true, false, true

print(nor[[a == b, b == a and c == d, c]])
print(nor[[a, b, c, d]])


