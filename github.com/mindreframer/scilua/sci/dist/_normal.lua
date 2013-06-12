--------------------------------------------------------------------------------
-- Normal statistical distribution.
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

local M = {}

local err, chk = xsys.handlers("sci.dist")
local exp, log, sqrt, pi, sin, cos, iseven, abs, ceil = xsys.from(math,
     "exp, log, sqrt, pi, sin, cos, iseven, abs, ceil")
      
-- Inverse cdf for sampling ----------------------------------------------------

-- Based on Peter John Acklam inverse cdf function, see:
-- http://home.online.no/~pjacklam/notes/invnorm/ .
-- Maximum relative error of 1.15E-9, fine for generation of rv.
-- Following paper has some considerations on this topic:
-- http://epub.wu.ac.at/664/1/document.pdf .

local a = ffi.new("double[7]", { 0,
-3.969683028665376e+01,
2.209460984245205e+02,
-2.759285104469687e+02,
1.383577518672690e+02,
-3.066479806614716e+01,
2.506628277459239e+00 })

local b = ffi.new("double[6]", { 0,
-5.447609879822406e+01,
1.615858368580409e+02,
-1.556989798598866e+02,
6.680131188771972e+01,
-1.328068155288572e+01 })

local c = ffi.new("double[7]", { 0,
-7.784894002430293e-03,
-3.223964580411365e-01,
-2.400758277161838e+00,
-2.549732539343734e+00,
4.374664141464968e+00,
2.938163982698783e+00 })

local d = ffi.new("double[5]", { 0,
7.784695709041462e-03,
3.224671290700398e-01,
2.445134137142996e+00,
3.754408661907416e+00 })

-- PERF: just two branches, central with high prob.
local function icdf(p)
  --Rational approximation for central region:
  if abs(p - 0.5) < 0.47575 then -- 95.14% of cases if p - U(0, 1).
    local q = p - 0.5
    local r = q^2
    return (((((a[1]*r+a[2])*r+a[3])*r+a[4])*r+a[5])*r+a[6])*q /
           (((((b[1]*r+b[2])*r+b[3])*r+b[4])*r+b[5])*r+1)
  --Rational approximation for the two ends:
  else
    local iu = ceil(p - 0.97575)	    -- 1 if p > 0.97575 (upper).
    local z = (1 - iu)*p + iu*(1 - p) -- p if lower, (1 - p) if upper.
    local sign = 1 - 2*iu	            -- 1 if lower, -1	if upper.
    local q = sqrt(-2*log(z))
    return sign*(((((c[1]*q+c[2])*q+c[3])*q+c[4])*q+c[5])*q+c[6]) /
                 ((((d[1]*q+d[2])*q+d[3])*q+d[4])*q+1)
  end
end
      
local norm_mt, norm_ct = {}
norm_mt.__index = norm_mt

function norm_mt:range()
  return -math.huge, math.huge
end

function norm_mt:pdf(x)
  local mu, sigma = self._mu, self._sigma
  return exp(-0.5*((x - mu)/sigma)^2) / (sqrt(2*pi)*sigma)
end

function norm_mt:logpdf(x)
  local mu, sigma = self._mu, self._sigma
  return -0.5*((x - mu)/sigma)^2 - 0.5*log(2*pi) - log(sigma)
end

function norm_mt:mean()
  return self._mu
end

function norm_mt:variance()
  return self._sigma^2
end

function norm_mt:absmoment(mm)
  if self._mu == 0 and self._sigma == 1 and mm == 1 then
    return sqrt(pi/2)
  else
    error("NYI")
  end
end

-- -- Box-muller cannot be used with our qrng API:
-- local function box_muller(self, u1, u2)
	-- -- Non-rejection sampler.
	-- local mu, sigma = self._mu, self._sigma
	-- local m  = sqrt(-2*log(u1))
	-- local r1 = m*cos(2*pi*u2) -- Gaussian(0,1).	
	-- local r2 = m*sin(2*pi*u2) -- Gaussian(0,1).
	-- return mu + sigma*r1, mu + sigma*r2
-- end

-- TODO: investigate ziggurat.
function norm_mt:sample(rng)
  return icdf(rng:sample())*self._sigma + self._mu
end

function norm_mt:copy()
  return norm_ct(self)
end

norm_ct = ffi.metatype("struct {double _mu; double _sigma;}", norm_mt)

M._normal_mt = norm_mt

function M.normal(mu, sigma)
  mu    = mu    or 0
  sigma = sigma or 1
  chk(sigma > 0, "constraint", "sigma must be positive, sigma=", sigma)
  return norm_ct(mu, sigma)
end

return M