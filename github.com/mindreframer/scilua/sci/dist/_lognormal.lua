--------------------------------------------------------------------------------
-- Lognormal statistical distribution.
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
local normd = require "sci.dist._normal"

local M = {}

local err, chk = xsys.handlers("sci.dist")
local exp, log, sqrt, pi = xsys.from(math, "exp, log, sqrt, pi")

local logn_mt, logn_ct = {}
logn_mt.__index = logn_mt

function logn_mt:range()
  return 0, math.huge
end

function logn_mt:pdf(x)
  if x < 0 then return 0 end
  local mu, sigma = self._mu, self._sigma
  return exp(-(log(x) - mu)^2/(2*sigma^2)) / (x*sqrt(2*pi)*sigma)
end

function logn_mt:logpdf(x)
  if x < 0 then return -math.huge end
  local mu, sigma = self._mu, self._sigma
  return -(log(x) - mu)^2/(2*sigma^2) - log(x*sqrt(2*pi)*sigma)
end

function logn_mt:mean()
  return exp(self._mu + 0.5*self._sigma^2)
end

function logn_mt:variance()
  return (exp(self._sigma^2) - 1)*exp(2*self._mu + self._sigma^2)
end

local sample = normd._normal_mt.sample

function logn_mt:sample(rng)
  return exp(sample(self, rng))
end

function logn_mt:copy()
  return logn_ct(self)
end

logn_ct = ffi.metatype("struct { double _mu; double _sigma; }", logn_mt)

function M.lognormal(mu, sigma)
  mu    = mu    or 0
  sigma = sigma or 1
  chk(sigma > 0, "constraint", "sigma must be positive, sigma=", sigma)
  return logn_ct(mu, sigma)
end

return M