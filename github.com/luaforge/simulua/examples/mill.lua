-- mill.lua
-- Mill model, example 19.1 from
-- Pooley, R., "An introduction to programming in Simula"
-- http://www.macs.hw.ac.uk/~rjp/bookhtml

local simulua = require "simulua"

-- variables
local count = 0

-- processes
local mill = {components = 0}
mill = simulua.process(function()
  while true do
    print("Machine starts", simulua.time())
    while mill.components > 0 do
      simulua.hold(2) -- machining time for one component
      mill.components = mill.components - 1
    end
    simulua.passivate()
  end
end, mill)

local worker = simulua.process(function()
  while simulua.time() < 400 do
    print("Loading starts", simulua.time())
    count = count + 1 -- keep a tally
    simulua.hold(5)
    mill.components = mill.components + 50 -- load up
    simulua.activate(mill) -- restart machine
    while mill.components > 0 do simulua.hold(0.5) end -- check regularly
    simulua.cancel(mill) -- switch off
    simulua.hold(10) -- unloading takes longer
    print("Unloading finishes", simulua.time())
  end
  simulua.passivate()
end)

-- simulation
simulua.start(function() -- main
  simulua.activate(worker)
  print(string.format("count = %d", count))
  simulua.hold(800)
  print("Simulation ends", simulua.time())
end)

