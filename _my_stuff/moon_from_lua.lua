#!/usr/bin/env luajit

--  http://moonscript.org/reference/

require 'moonscript'

-- things is a moonscript file
require 'things'

-- it works, the things module is present and usable from lua
local person = things.Person()
person.name = "George W. Bush"
person:say_name()
