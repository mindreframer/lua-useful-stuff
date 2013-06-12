local zm = require'zbus.member'
-- load the JSON message format serilization
local zbus_json_config = require'zbus.json'
-- create a zbus member with the specified serializers
local member = zm.new(zbus_json_config)
-- call the service function and pass some arguments
local res = {member:call(
	'echo', -- the method url/name
	'Hello',123,'is my number',{stuff=8181} -- the arguments
     )}
assert(res[1]=='Hello')
assert(res[2]==123)
assert(res[3]=='is my number')
assert(res[4].stuff==8181)
