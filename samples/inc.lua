#!/usr/bin/env luma

meta[[

luma.define_simple("inc", "$1 = $1 + 1")

luma.define_simple("inc_e", "(function () $1 = $1 + 1; return $1 end)()")

]]

local a = 2

inc[[a]]

print(a)

print(inc_e[[a]])

print(a)

