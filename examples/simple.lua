require "leslie"

local t = leslie.Template([[Hello world - powered by {{ name }} {{ version }}.]])

print(t:render({ name = "Leslie", version = leslie.version }))
