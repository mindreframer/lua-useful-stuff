-- interference.lua
-- The "machine interference model" from Section 3.2 of
-- Mitrani, I. (1982), "Simulation techniques for discrete event systems"

local simulua = require "simulua"
local rng = require "rng"
local queue = require "queue"

-- variables
local u = rng() -- note: change seed for different runs
local downtime, breaks = 0, 0
local broken, available = queue(), queue()

-- parameters
local brk, rep = 3, 5 -- break and repair means
local m, r = 5, 2 -- number of machines and repairmen
local simtime = 1000 -- simulation period

local function machine ()
  local self, lastbreak = {}
  return simulua.process(function()
    while true do
      simulua.hold(u:exp(brk))
      broken:into(self) -- insert
      lastbreak = simulua.time()
      if not available:isempty() then
        simulua.activate(available:front())
      end
      simulua.passivate()
      breaks = breaks + 1
      downtime = downtime + simulua.time() - lastbreak
    end
  end, self)
end

local function repairman ()
  local self = {}
  return simulua.process(function()
    while true do
      available:retrieve() -- self out
      while not broken:isempty() do
        local mach = broken:retrieve()
        simulua.hold(u:exp(rep))
        simulua.activate(mach)
      end
      available:into(self) -- insert
      simulua.passivate()
    end
  end, self)
end

simulua.start(function()
  for i = 1, m do
    simulua.activate(machine())
  end
  for i = 1, r do
    simulua.activate(repairman())
  end
  simulua.hold(simtime)
  print(string.format("Average inoperative period: %.2f",
    downtime / breaks))
end)

