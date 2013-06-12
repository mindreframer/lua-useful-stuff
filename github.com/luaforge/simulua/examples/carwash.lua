-- carwash.lua
-- Car wash simulation from Section 9.2 in
-- Birtwistle, G. M., *et al.* (1981), "SIMULA *BEGIN*"

local simulua = require "simulua"
local queue = require "queue"
local rng = require "rng"

-- simulator: p is service mean, n is number of car washers
local function washingcars (p, n, simperiod, seed)
  local tearoom, waitingline = queue(), queue()
  local throughtime, ncustomers, maxlength = 0, 0, 0
  local r = rng(seed)
  local function report ()
    print(string.format("%2d CAR WASHER SIMULATION", n))
    print(string.format("NO. OF CARS THROUGH THE SYSTEM=%6d", ncustomers))
    print(string.format("AV. ELAPSED TIME=%9.2f", throughtime / ncustomers))
    print(string.format("MAXIMUM QUEUE LENGTH=%4d", maxlength))
  end
  -- processes
  local function car ()
    local self = {}
    return simulua.process(function()
      local entrytime = simulua.time()
      waitingline:into(self)
      local qlength = #waitingline
      if maxlength < qlength then maxlength = qlength end
      if not tearoom:isempty() then
        simulua.activate(tearoom:front())
      end
      simulua.passivate()
      local elapsedtime = simulua.time() - entrytime
      ncustomers = ncustomers + 1
      throughtime = throughtime + elapsedtime
    end, self)
  end
  local function carwasher ()
    return simulua.process(function()
      while true do
        tearoom:retrieve() -- self out
        while not waitingline:isempty() do
          local served = waitingline:retrieve()
          simulua.hold(10)
          simulua.activate(served)
        end
        simulua.wait(tearoom)
      end
    end)
  end
  local cargen = simulua.process(function()
    while simulua.time() < simperiod do
      simulua.activate(car())
      simulua.hold(r:exp(p))
    end
  end)
  -- simulation
  simulua.start(function()
    for i = 1, n do tearoom:into(carwasher()) end
    simulua.activate(cargen)
    simulua.hold(simperiod + 1e6)
    report()
  end)
end

washingcars(11, 1, 200, 5)
washingcars(11, 2, 200, 5)

