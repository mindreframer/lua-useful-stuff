local config = require'zbus.json'
local service = require'zbus.member'.new(config)

service:replier_add(
   '^echo$',
   function(_,...)
      return ...
   end)

service:loop()
