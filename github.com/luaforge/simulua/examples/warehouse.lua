-- warehouse.lua
-- The "versatile warehouse model" from Section 3.1 of
-- Mitrani, I. (1982), "Simulation techniques for discrete event systems"

local simulua = require "simulua"
local rng = require "rng"
local queue = require "queue"

-- variables
local r = rng() -- note: change seed for different runs
local warehouse = simulua.accumulator() -- for number of items
local n = 0 -- number of current items in warehouse
local arrived, rejected = 0, 0 -- number of items

-- parameters
local arr, rem = 20, 10 -- arrival and removal means
local in1, in2 = 3, 5  -- range for arrivals
local out1, out2 = 4, 6 -- range for removals
local m = 10 -- units of storage
local simperiod = 1000 -- simulation period

-- processes
local arrivals, worker
do -- arrivals
  local number -- of items in batch
  arrivals = simulua.process(function()
    while true do
      simulua.hold(r:exp(arr))
      arrived = arrived + 1
      number = r:unifint(in1, in2)
      if number > m - n then
        rejected = rejected + 1
      else
        warehouse:update(n)
        n = n + number
        if simulua.idle(worker) then
          simulua.activate(worker)
        end
      end
    end
  end)
end
do -- worker
  local size, number -- size of outgoing batch and number removed
  worker = simulua.process(function()
    while true do
      while n > 0 do
        simulua.hold(r:exp(rem))
        warehouse:update(n)
        size = r:unifint(out1, out2)
        number = size < n and size or n
        n = n - number
      end
      simulua.passivate() -- warehouse is now empty
    end
  end)
end

-- simulation
simulua.start(function()
  simulua.activate(arrivals)
  simulua.activate(worker)
  simulua.hold(simperiod)
  print(string.format("Proportion of rejected batches: %.2f",
    rejected / arrived))
  print(string.format("Average no. of items in warehouse: %.2f",
    warehouse.mean))
end)

