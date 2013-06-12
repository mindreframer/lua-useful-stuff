#!/usr/bin/env luma

require_for_syntax[[class]]

require"foo"

local o = foo.new("Hello")

print(o:say("world!"))
