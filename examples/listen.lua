#!/usr/bin/env lua
-- make sure zbusd is started before execution!
local zm = require'zbus.member'

local member = zm.new()

-- simply subscribe notification given as parameter or all notfifications for printout
member:listen_add(arg[1] or '.*', print)

member:loop()
