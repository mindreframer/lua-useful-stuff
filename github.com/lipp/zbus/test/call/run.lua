local testutils = require'zbus.testutils'
local zbusd = testutils.process('bin/zbusd.lua')
local echo = testutils.process('lua test/call/echo.lua')
testutils.sleep(0.3)
local caller = testutils.process('lua test/call/caller.lua')
assert(caller:wait()==0)

echo:kill()
echo:wait()
zbusd:kill()
zbusd:wait()

