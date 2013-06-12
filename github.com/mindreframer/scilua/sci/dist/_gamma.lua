--------------------------------------------------------------------------------
-- Gamma statistical distribution.
--
-- Copyright (C) 2011-2012 Stefano Peluchetti. All rights reserved.
--
-- Features, documention and more: http://www.scilua.org .
--
-- This file is part of the SciLua library, which is released under the MIT 
-- license: full text in file LICENSE.TXT in the library's root folder.
--------------------------------------------------------------------------------

local xsys  = require "xsys"
local ffi   = require "ffi"
local math  = require "sci.math"
local normd = require "sci.dist._normal"
local expod = require "sci.dist._exponential"

local M = {}

local err, chk = xsys.handlers("sci.dist")
local exp, log, sqrt, min, gamma, logabsgamma, max, ceil = xsys.from(math, 
     "exp, log, sqrt, min, gamma, logabsgamma, max, ceil")

local gamm_mt, gamm_ct = {}
gamm_mt.__index = gamm_mt

function gamm_mt:range()
  return 0, math.huge
end

function gamm_mt:pdf(x)
  if x < 0 then return 0 end
  local a, b = self._a, self._b
  return b^a * x^(a - 1) * exp(-b*x) / gamma(a)
end

function gamm_mt:logpdf(x)
  if x < 0 then return -math.huge end
  local a, b = self._a, self._b
  return a*log(b) - logabsgamma(a) + (a - 1)*log(x) - b*x
end

function gamm_mt:mean()
  return self._a/self._b
end

function gamm_mt:variance()
  return self._a/self._b^2
end

local nd01 = normd.normal(0, 1)

-- Based on Marsaglia-Tsang method, valid for a >= 1, see:
-- http://www.cparity.com/projects/AcmClassification/samples/358414.pdf .
-- PERF: not worth checking for v <= 0 separately.
local function sample(a, b, rng)
  local d = a - 1/3
  local c = 1/sqrt(9*d)
  
  do -- PERF: avoid (>95% of the time) problematic loop below with this: 
    local x = nd01:sample(rng)
    local v = (1 + c*x)^3
    local u = rng:sample()
    if min(v, 1 - 0.0331*x^4 - u) > 0 -- Squeeze, around 92% of the time.
    or min(v, -log(u) + 0.5*x^2 + d*(1 - v + log(v))) > 0 then
      return v*d/b -- v*d ~ gamma(a), scaling: v*d/b ~ gamma(a, b).
    end
  end
  
  -- PERF: better this than 'repeat until' alternative, as it allows to return
  -- PERF: directly from whithin the loop:
  while true do
    local x = nd01:sample(rng)
    local v = (1 + c*x)^3
    -- PERF: squeeze step not worth here.
    if min(v, -log(rng:sample()) + 0.5*x^2 + d*(1 - v + log(v))) > 0 then
      return v*d/b -- v*d ~ gamma(a), scaling: v*d/b ~ gamma(a, b).
    end
  end
end

local sample_disp = {
  [false] = function(a, b, rng)
    return sample(a, b, rng)
  end,
  [true] = function(a, b, rng)
    local y = sample(a + 1, b, rng)
    return rng:sample()^(1/a)*y
  end,
}
M._sample_disp = sample_disp

-- TODO: Assert prng!
function gamm_mt:sample(rng)
  return sample_disp[self._i](self._a, self._b, rng)
end

function gamm_mt:copy()
  return gamm_ct(self)
end

gamm_ct = ffi.metatype("struct { double _a; double _b; bool _i; }", gamm_mt)

function M.gamma(alpha, beta)
  alpha = alpha or 1
  beta  = beta  or 1
  chk(alpha > 0 and beta > 0, "constraint", 
      "alpha and beta must be positive, alpha=", alpha, ", beta=", beta)
  return gamm_ct(alpha, beta, alpha < 1)
end

return M