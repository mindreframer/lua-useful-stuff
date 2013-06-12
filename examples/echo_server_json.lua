local zm = require'zbus.member'
-- load the JSON message format serilization
local zbus_json_config = require'zbus.json'
-- create a zbus member with the specified serializers
local member = zm.new(zbus_json_config)
-- register a function, which will be called, when a zbus-message's url matches expression
member:replier_add(
	 -- the expression to match	
          '^echo$', 
	  -- the callback gets passed in the matched url, in this case always 'echo', and the unserialized argument string	
          function(url,...) 
		print(url,...)
		return ...
          end)

-- start the event loop, which will forward all 'echo' calls to member.
member:loop()
