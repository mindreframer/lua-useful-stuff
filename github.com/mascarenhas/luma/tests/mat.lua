#!/usr/bin/env luma

require_for_syntax[[match]]

local ran_ft = false

match [[
  subject "Hello World!"
  with foo <- [[ "Hello" {.+} ]] do
    assert(foo == " World!")
    fallthrough
  with bar <- [[ "Hello Wor" {...} ]] do
    assert(bar == "ld!")
    ran_ft = true
  with <- [[ "H" .* ]] do
    assert(false)
  default
    assert(false)
  end
]]

assert(ran_ft)
