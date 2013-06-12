local socket = require'socket'
local zsocket = require'zbus.socket'
local testutils = require'zbus.testutils'

local sock = socket.connect('localhost',6669)
local wsock = zsocket.wrap_sync(sock)

local messages = {
   {'abc'},
   {'abc','qqqqqq'},
   {'abc','qqqqqq','asdddwpwpqpw'}
}

for _,message in ipairs(messages) do
   wsock:send_message(message)
   local resp = wsock:receive_message()
   local match = testutils.deepcompare(message,resp)
   if not match then
      failed = true
   end
end

if failed then
   print('exiting',1)
   os.exit(1)
end
print('exiting',0)
os.exit(0)

