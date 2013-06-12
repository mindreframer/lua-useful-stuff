local simulua = require "simulua"
local queue = require "queue"
local rng = require "rng"
local cdf = require "cdf"

local r, pnorm = rng(os.time()), cdf.pnorm
local sqrt, max, min = math.sqrt, math.max, math.min

local n = 5 -- # of customers
local simperiod = 200
local waitingline = queue()
local transaction = {} -- successful transaction at current time?

local history = {} -- log price evolution

local vendor = {price = 10, var = 1, threshold = 5, weight = 50}
vendor = simulua.process(function()
  while true do
    history[simulua.time()] = {}
    while not waitingline:isempty() do
      local customer = waitingline:retrieve()
      local u = customer.price - vendor.price
      u = (1 - pnorm(-u / sqrt(customer.var))) * pnorm(u / sqrt(vendor.var))
      transaction[customer] = r:unif() < u -- Bernoulli sample
      simulua.activate(customer)
    end
    -- update price
    local m = vendor.weight * vendor.price / vendor.var
    local v = vendor.weight / vendor.var
    for customer, ok in pairs(transaction) do
      local t, s
      if ok then
        t, s = vendor.price, vendor.var
      else
        t, s = customer.price, customer.var
      end
      m = m + t / s
      v = v + 1 / s
    end
    vendor.price = max(r:norm(m / v, sqrt(1 / v)), vendor.threshold)
    history[simulua.time()][0] = vendor.price
    simulua.hold(1) -- wait for next tick
  end
end, vendor)

local function customer (name, price, var, threshold, weight)
  local self = {price = price, var = var}
  return simulua.process (function()
    while true do
      simulua.wait(waitingline)
      -- update price
      local m, v = weight * self.price / self.var, weight / self.var
      local t, s
      if transaction[self] then
        t, s = self.price, self.var
      else
        t, s = vendor.price, vendor.var
      end
      m = m + t / s
      v = v + 1 / s
      self.price = max(min(r:norm(m / v, sqrt(1 / v)), threshold), 0)
      history[simulua.time()][name] = self.price
      simulua.hold(0.5) -- any time t, 0 < t < 1
    end
  end, self)
end

simulua.start(function()
  simulua.hold(1)
  for i = 1, n do
    simulua.activate(customer(i, 1, i, 5, 50))
  end
  simulua.activate(vendor)
  simulua.hold(simperiod)
end)

-- report
io.write"time\tvendor"
for c = 1, n do io.write(string.format("\tcust%d", c)) end
io.write"\n"
for i, l in ipairs(history) do
  io.write(string.format("%d\t%.2f", i, l[0]))
  for c = 1, n do io.write(string.format("\t%.2f", l[c])) end
  io.write"\n"
end

