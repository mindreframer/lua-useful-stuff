local testutils = require'zbus.testutils'

local server = testutils.process('lua test/simple_message/echo_server.lua')
local client = testutils.process('lua test/simple_message/echo_client.lua')

testutils.sleep(0.3)
assert(client:wait()==0)

server:kill()
server:wait()
