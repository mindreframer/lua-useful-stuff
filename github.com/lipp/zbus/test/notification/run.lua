local testutils = require'zbus.testutils'
local zbusd = testutils.process('bin/zbusd.lua')
local publisher = testutils.process('lua test/notification/publisher.lua')
local subscriber = testutils.process('lua test/notification/subscriber.lua')
assert(subscriber:wait()==0)
publisher:kill()
publisher:wait()
zbusd:kill()
zbusd:wait()
