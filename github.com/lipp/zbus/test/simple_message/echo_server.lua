local ev = require'ev'
local zsocket = require'zbus.socket'

local echo_server = zsocket.listener(
   6669,
   function(client)           
      client:on_message(
         function(parts) 
            client:send_message(parts)
         end)
   end)
echo_server.io:start(ev.Loop.default)

ev.Loop.default:loop()
