
----------------------------------------------------------------------------
--  service_client.lua - service client example
--
--  Created: Fri Jul 30 10:58:59 2010 (at Intel Research, Pittsburgh)
--  Copyright  2010  Tim Niemueller [www.niemueller.de]
--  Licensed under BSD license, cf. LICENSE file of roslua
----------------------------------------------------------------------------

require("roslua")

roslua.init_node{node_name="serviceclient"}

-- Number of iterations to call the service
local LOOPS = 3
-- Sleep 5 seconds after each iteration but the last?
local SLEEP_PER_LOOP = false

local service = "add_two_ints"
local srvtype = "rospy_tutorials/AddTwoInts"

local s = roslua.service_client(service, srvtype, {simplified_return=true})
math.randomseed(os.time())

for i = 1, LOOPS do
   local a, b = math.random(1000), math.random(1000)

   -- Use simple form without concurrent execution
   local ok, res = pcall(s, {a, b})
      
   if ok then
      print(a .. " + " .. b .. " = " .. res)
   else
      printf("%s", res)
   end

   -- Sleep after loop, for example to restart provider in between loops
   if i ~= LOOPS and SLEEP_PER_LOOP then roslua.sleep(5.0) end
end

roslua.finalize()
