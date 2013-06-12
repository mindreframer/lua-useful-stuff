--------------------------------------------------------------------------------
-- Uniform statistical distribution.
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
local alg  = require "sci.alg"

local M = {}

local err, chk = xsys.handlers("sci.dist")
local log = math.log
local sum, prod, elog = alg.sum, alg.prod, alg.log

local unif_mt, unif_ct = {}
unif_mt.__index = unif_mt

function unif_mt:range()
  return self._a, self._b
end

function unif_mt:pdf(x)
  return 1/(self._b - self._a)
end

function unif_mt:logpdf(x)
  return -log(self._b - self._a)
end

function unif_mt:mean()
  return 0.5*(self._a + self._b)
end

function unif_mt:variance()
  return (self._b - self._a)^2/12
end

function unif_mt:sample(rng)
  return self._a + (self._b - self._a)*rng:sample()
end

function unif_mt:copy()
  return unif_ct(self)
end

unif_ct = ffi.metatype("struct { double _a; double _b; }", unif_mt)

function M.uniform(a, b)
  a = a or 0
  b = b or 1
  chk(a < b, "constraint", "a < b required, a=", a, ", b=", b)
  return unif_ct(a, b)
end

-- Md --------------------------------------------------------------------------
local mdunif_mt, mdunif_ct = {}
mdunif_mt.__index = mdunif_mt

function mdunif_mt:dim()
  return #self._a
end

function mdunif_mt:pdf(x)
  return 1/prod((self._b - self._a))
end

function mdunif_mt:logpdf(x)
  return -sum(elog(self._b - self._a))
end

function mdunif_mt:sample(rng, x)
  x:gen(rng.sample, rng)
  return x:set(self._a + (self._b - self._a)*x)
end

-- TODO: Mike: Is this the best way to manage aggregate structs?
-- Proposal for __new and __gc in aggregate structs.
function mdunif_mt:__gc()
  self._a:__gc()
  self._b:__gc()
end

function mdunif_mt:copy()
  return mdunif_ct(self._a:copy(), self._b:copy())
end

local mdunif_t = ffi.typeof("struct { $ _a; $ _b; }", alg.vec_ct, alg.vec_ct)

mdunif_ct = ffi.metatype(mdunif_t, mdunif_mt)

-- TODO: Mike: Is this the best way to manage aggregate structs?
-- Proposal for __new and __gc in aggregate structs.
function M.mduniform(a, b)
  alg.check.eqsize(a, b)
  -- TODO: get back check.
  --chk(a < b, "constraint", "a < b required, a=", a, ", b=", b)
  local ac, bc = a:copy(), b:copy()
  local o = mdunif_ct(ac, bc)
  ac._p1, bc._p1 = nil, nil
  return o
end

return M