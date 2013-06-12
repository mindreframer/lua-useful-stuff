--------------------------------------------------------------------------------
-- Beta statistical distribution.
--
-- Copyright (C) 2011-2012 Stefano Peluchetti. All rights reserved.
--
-- Features, documention and more: http://www.scilua.org .
--
-- This file is part of the SciLua library, which is released under the MIT 
-- license: full text in file LICENSE.TXT in the library's root folder.
--------------------------------------------------------------------------------

local xsys = require "xsys"
local ffi  = require "ffi"
local math = require "sci.math"
local gamd = require "sci.dist._gamma"

local M = {}

local err, chk = xsys.handlers("sci.dist")
local exp, log, sqrt, min, beta, logbeta = xsys.from(math, 
     "exp, log, sqrt, min, beta, logbeta")

local beta_mt, beta_ct = {}
beta_mt.__index = beta_mt

function beta_mt:range()
  return 0, 1
end

function beta_mt:pdf(x)
  if x < 0 or x > 1 then return 0 end
  local a, b = self._a, self._b
  return x^(a - 1) * (1 - x)^(b - 1) / beta(a, b)
end

function beta_mt:logpdf(x)
  if x < 0 or x > 1 then return -math.huge end
  local a, b = self._a, self._b
  return (a - 1)*log(x) + (b - 1)*log(1 - x) - logbeta(a, b)
end

function beta_mt:mean()
  return self._a/(self._a + self._b)
end

function beta_mt:variance()
  local a, b = self._a, self._b
  return (a*b)/((a + b)^2*(a + b + 1))
end

local sample_disp = gamd._sample_disp

-- T0D0: Assert prng!
function beta_mt:sample(rng)
  local x = sample_disp[self._i1](self._a, 1, rng)
  local y = sample_disp[self._i2](self._b, 1, rng)
  return x/(x + y)
end

function beta_mt:copy()
  return beta_ct(self)
end

beta_ct = ffi.metatype("struct { double _a; double _b; bool _i1; bool _i2; }",
                       beta_mt)
                       
function M.beta(alpha, beta)
  alpha = alpha or 1
  beta  = beta  or 1
  chk(alpha > 0 and beta > 0, "constraint", 
      "alpha and beta must be positive, alpha=", alpha, ", beta=", beta)
  return beta_ct(alpha, beta, alpha < 1, beta < 1)
end

return M