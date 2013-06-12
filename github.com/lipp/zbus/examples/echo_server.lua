local zm = require'zbus.member'
local member = zm.new{
   log = print
}
-- register a function, which will be called, when a zbus-message's url matches expression
member:replier_add(
	 -- the expression to match	
          '^echo$', 
	  -- the callback gets passed in the matched url, in this case always 'echo', and the argument string
          function(url,argument_str) 
		print(url,argument_str)
		return argument_str
          end)

-- start the event loop, which will forward all 'echo' calls to member.
member:loop()
