local config = require'zbus.json'
local service = require'zbus.member'.new(config)

service:replier_add(
   '^echo$',
   function(_,...)
      local args = {...}
      for i,arg in ipairs(args) do
         local more = i~=#args
         service:notify('echoing_'..i,more,arg)
      end
      return ...
   end)

service:loop()
