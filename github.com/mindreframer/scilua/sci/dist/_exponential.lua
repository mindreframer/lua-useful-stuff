--------------------------------------------------------------------------------
-- Exponential statistical distribution.
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

local M = {}

local err, chk = xsys.handlers("sci.dist")
local exp, log = math.exp, math.log

local expo_mt, expo_ct = {}
expo_mt.__index = expo_mt

function expo_mt:range()
  return 0, math.huge
end

function expo_mt:pdf(x)
  if x < 0 then return 0 end
  return self._lambda*exp(-self._lambda*x)
end

function expo_mt:logpdf(x)
  if x < 0 then return -math.huge end
  return log(self._lambda) -self._lambda*x
end

function expo_mt:mean()
  return 1/self._lambda
end

function expo_mt:variance()
  return 1/self._lambda^2
end

function expo_mt:sample(rng)
  return -log(rng:sample())/self._lambda
end

function expo_mt:copy()
  return expo_ct(self)
end

expo_ct = ffi.metatype("struct { double _lambda; }", expo_mt)

function M.exponential(lambda)
  lambda = lambda or 1
  chk(lambda > 0, "constraint", "lambda must be positive, lambda=", lambda)
  return expo_ct(lambda)
end

return M