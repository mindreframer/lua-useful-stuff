-- office.lua
-- Simulation with two time periods, example 19.3 from
-- Pooley, R., "An introduction to programming in Simula"
-- http://www.macs.hw.ac.uk/~rjp/bookhtml

local simulua = require "simulua"
local queue = require "queue"

-- variables
local count, typingpool, photocopier
local document = function() return {} end -- dummy document class
local function report ()
  print("*** Report ***")
  print(string.format("%d documents printed, at time %.1f", count,
      simulua.time()))
end

-- processes
local function writer ()
  local self = {doc = true}
  return simulua.process(function()
    while true do
      simulua.hold(8)
      self.doc = document()
      local typist = typingpool:retrieve()
      simulua.activate(typist)
    end
  end, self)
end

local function typer ()
  return simulua.process(function()
    simulua.wait(typingpool)
    while true do
      simulua.hold(4)
      simulua.activate(photocopier)
      simulua.wait(typingpool)
    end
  end)
end

local function copier ()
  return simulua.process(function()
    while true do
      simulua.hold(1)
      count = (count or 0) + 1
      print(string.format("Document %d printed at %.1f",
        count, simulua.time()))
      simulua.passivate()
    end
  end)
end

-- simulation
simulua.start(function()
  typingpool = queue()
  for i = 1, 10 do
    simulua.activate(typer())
  end
  photocopier = copier()
  simulua.activate(writer(), 2)
  simulua.activate(writer(), 4.5)
  simulua.hold(100)
  report()
  simulua.hold(100)
  report()
end)

