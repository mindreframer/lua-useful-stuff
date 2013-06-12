--------------------------------------------------------------------------------
-- Sobol quasi random number generator module.
--
-- Copyright (C) 2011-2012 Stefano Peluchetti. All rights reserved.
--
-- Features, documention and more: http://www.scilua.org .
--
-- Credit: this implementation is based on the code published at:
-- http://web.maths.unsw.edu.au/~fkuo/sobol/ .
-- Please notice that the code written in this file is NOT endorsed in any way 
-- by the authors of the original C++ code (on which this implementation is
-- based), S. Joe and F. Y. Kuo, nor they participated in the development of 
-- this Lua implementation.
-- Any bug / problem introduced in this port is my sole responsibility.
--
-- This file is part of the SciLua library, which is released under the MIT 
-- license: full text in file LICENSE.TXT in the library's root folder.
--------------------------------------------------------------------------------

local ffi      = require "ffi"
local xsys     = require "xsys"
local alg      = require "sci.alg"
local dirndata = require "sci.qrng._new-joe-kuo-6-21201"

local M = {}

local err, chk = xsys.handlers("sci.qrng")
local bit = xsys.bit
local tobit, lshift, rshift = bit.tobit, bit.lshift, bit.rshift
local band, bor, bxor, lsb =  bit.band, bit.bor, bit.bxor, bit.lsb

local alg32 = alg.typeof(ffi.typeof("int32_t"))

local sobol_t = ffi.typeof([[
struct {
  $        _x; // State.
  int32_t  _n; // Counter.
  int32_t  _o; // Offset.
  int32_t  _s; // Status.
} ]], alg32.vec_ct)

-- For background see:
-- http://web.maths.unsw.edu.au/~fkuo/sobol/joe-kuo-notes.pdf .
local m = dirndata.m -- Sequence of positive integers.
local a = dirndata.a -- Primitive polynomial coefficients.

-- Direction numbers: 32 bits * 21201 dimensions.
-- Maximum number of samples is 2^32-1 (the origin, i=0, is discarded).
local v = alg32.mat(32, 21201)

-- Fill direction numbers for first dimension, all m = 1.
for i=1,32 do v[i][1] = lshift(1, 32-i) end

local maxdim = 1 -- Current maximum dimension.

local function compute_dn(dim) -- Fill direction numbers up to dimension dim.
  chk(dim <= 21201, "constraint", "Sobol qrng allows up to 21201 dimensions, ",
      dim, " requested")
  if dim > maxdim then -- Maxdim is max dimension computed up to now.
    for j=maxdim+1, dim do -- Compute missing dimensions.
      local s = #m[j]
      for i=1,s do 
        v[i][j] = lshift(m[j][i], 32-i)
      end
      for i=s+1,32 do
        v[i][j] = bxor(v[i-s][j], rshift(v[i-s][j], s))
        for k=1,s-1 do 
          v[i][j] = bxor(v[i][j], band(rshift(a[j], s-1-k), 1) * v[i-k][j])
        end
      end
    end
    maxdim = dim
  end
end

local sobol_mt, sobol_ct = {}
sobol_mt.__index = sobol_mt

-- TODO: Vectorize.
local function nextstate(self)
  local c = lsb(self._n) + 1  
  for i=1,#self._x do
    self._x[i] = bxor(self._x[i], v[c][i])
  end
  self._o = 0
end

-- Move rng to next state (exactly all dimensions must have been used).
function sobol_mt:nextstate()
  self._n = tobit(self._n + 1)
  if self._n <= 0 then
    if self._s == 0 then -- Zero iterations up to now.
      chk(self._o == 0, "misuse", "sample() called before nextstate()")
      self._n = -1 -- Get back to self._n = 0 condition next iteration.
      self._s = 1
      return
    elseif self._s == 1 then -- One iteration up to now, initializing.
      self._s = 2
      
      local v = alg32.vec(self._o) -- Create new.
      self._x:__gc() -- Collect old.
      self._x = v -- Copy struct data.
      v._p1 = nil -- Disable GC or wil be collected twice.
      
      compute_dn(self._o)
      -- Recover missed computations.
      self._n = 1
      nextstate(self)
      self._o = #self._x
      self._n = 2
    else
      err("error", "limit of 2^32-1 states exceeded in Sobol qrng")
    end
  end
  -- Usual operation.
  if not(self._o == #self._x) then
    err("misuse", self._o.." samples in qrng of dimensionality "..(#self._x))
  end
  nextstate(self)
end

-- Result between (0, 1) extremes excluded.
function sobol_mt:sample()
  self._o = self._o + 1
  return (bxor(self._x[self._o], 0x80000000) + 0x80000000)*(1/2^32)
end

function sobol_mt:__gc() self._x:__gc() end

sobol_ct = ffi.metatype(sobol_t, sobol_mt)

function M.sobol()
  -- -2^31 is state at first iteration, which is precomputed.
  local v = alg32.vec(21201, -2^31)
  local o = sobol_ct(v, -1, 0, 0)
  v._p1 = nil -- Disable GC.
  return o
end

return M