#!/usr/bin/env luma

require_for_syntax[[using]]

using [[

from math import random, pow

from cosmo import fill

]]

assert(random)
assert(pow(2,3) == 8)
assert(fill("Hello $msg!", { msg = "world" }) == "Hello world!")

import[[math]]

assert(sin)
assert(cos)

