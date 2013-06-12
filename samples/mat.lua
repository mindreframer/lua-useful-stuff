#!/usr/bin/env luma

require_for_syntax[[match]]

match [[
  subject "Hello World!"
  with foo <- [[ "Hello" {.+} ]] do
    print(foo)
    fallthrough
  with bar <- [[ "Hello Wor" {...} ]] do
    print(bar)
  with <- [[ "H" .* ]] do
    print("strike 3")
  default
    print("default")
  end
]]

