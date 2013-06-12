-- Debugging using the MobDebug library:
--https://github.com/pkulchenko/MobDebug

-- luarocks install mobdebug

-- open an interactive Lua session
-- run "require('mobdebug').listen()"
-- to turn on the remote debugging server

-- kick off a debug client
require('mobdebug').start()

print("Start")
local foo = 0
for i = 1, 3 do
  foo = i
  print("Loop")
end
print("End")
