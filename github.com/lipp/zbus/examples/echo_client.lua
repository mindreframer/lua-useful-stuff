local zm = require'zbus.member'
local member = zm.new()
-- call the service function
for i=1,arg[1] or 1 do
   local text = 'hello'..tostring(math.random(1,1000000))
  local result_str = member:call(
    'echo', -- the method url/name
    text -- the argument string
  )
  print(result_str)
  assert(result_str == text)
end
