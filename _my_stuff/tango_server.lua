#!/usr/bin/env lua

-- load tango module
local tango = require 'tango'

-- define a nice greeting function
greet = function(...)
  print(...)
end

-- start listening for client connections
tango.server.copas_socket.loop{
  port = 12345
}
