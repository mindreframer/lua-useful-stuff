#!/usr/bin/env lua
-- make sure zbusd is started before execution!
local zm = require("zbus.member")

local m = zm.new()
m:notify_more(arg[1] or "hallo",true,'aaaaa')
m:notify_more(arg[1] or "horst",false,'bbb')
