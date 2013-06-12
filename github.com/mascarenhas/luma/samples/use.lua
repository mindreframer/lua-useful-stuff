#!/usr/bin/env luma

require_for_syntax[[using]]

using [[

from math import random, pow

from cosmo import fill

]]

print(random())
print(pow(2,3))
print((fill("Hello $msg!", { msg = "world" })))

import[[math]]

print(sin(pi), cos(pi))

