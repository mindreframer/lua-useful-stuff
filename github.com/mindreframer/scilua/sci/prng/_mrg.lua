--------------------------------------------------------------------------------
-- Pierre L'Ecuyer MRG pseudo rngs module.
--
-- Copyright (C) 2011-2012 Stefano Peluchetti. All rights reserved.
--
-- Features, documention and more: http://www.scilua.org .
--
-- This file is part of the SciLua library, which is released under the MIT 
-- license: full text in file LICENSE.TXT in the library's root folder.
--------------------------------------------------------------------------------

-- TODO: replace tables with ULL matrixes and their operators?

local ffi = require "ffi"

local M = {}

-- TODO: improve and move to xsys.
local function sarg(...)
  return "("..table.concat({ ... }, ",")..")"
end

-- Return unsigned long long matrix(3, 3).
local function ulmat()
  return {{0ULL, 0ULL, 0ULL}, {0ULL, 0ULL, 0ULL}, {0ULL, 0ULL, 0ULL}}
end

local toul = ffi.typeof("uint64_t")

-- Constants defining the rng.
local a12   = 1403580
local a13   = -810728
local m1    = 2^32 - 209
local a21   = 527612
local a23   = -1370589
local m2    = 2^32 - 22853
local scale = 1/(m1 + 1)
local y0    = 12345

-- Return modular matrix product: X1*X2 % m. All matrixes (3, 3).
-- Require X1, X2 of uint64_t if m = 2^32 as products can go up almost 2^64.
local function modmul(X1, X2, m) 
  local Y = ulmat()
  for r=1,3 do
    for c=1,3 do
      local v = 0ULL
      for i=1,3 do
        local prod = (X1[r][i]*X2[i][c]) % m -- prod is uint64_t.
        v = (v + prod) % m -- v is uint64_t.
      end
      Y[r][c] = v
    end
  end
  return Y
end

-- Skip ahead matrixes valid for A^p with p = 2^i, i >= 1 (so p even).
local aheadA1, aheadA2 = {}, {}
do 
  local A1, A2 = ulmat(), ulmat() -- Initialized to 0ULL.
  A1[1][2] = toul(a12 % m1); A1[1][3] = toul(a13 % m1)
  A1[2][1] = 1ULL
  A1[3][2] = 1ULL 
  A2[1][1] = toul(a21 % m2); A2[1][3] = toul(a23 % m2)
  A2[2][1] = 1ULL
  A2[3][2] = 1ULL
  for i=1,128 do
    A1 = modmul(A1, A1, m1)
    aheadA1[i] = A1
    A2 = modmul(A2, A2, m2)
    aheadA2[i] = A2
  end
end

local mrg_mt, mrg_ct = {}
mrg_mt.__index = mrg_mt

-- Sampling algorithm (combine excluded), see pag. 11 of:
-- http://citeseerx.ist.psu.edu/viewdoc/summary?doi=10.1.1.48.1341 .
-- This rng, with this parameters set, allows to keep the state info in 
-- double precision numbers (i.e. Lua numbers).
function mrg_mt:sample()
  -- assert(math.abs(a12*self._y12 + a13*self._y13) < 2^53)
  local p1 = (a12*self._y12 + a13*self._y13) % m1
  self._y13 = self._y12; self._y12 = self._y11; self._y11 = p1  
  -- assert(math.abs(a21*self._y21 + a23*self._y23) < 2^53)
  local p2 = (a21*self._y21 + a23*self._y23) % m2
  self._y23 = self._y22; self._y22 = self._y21; self._y21 = p2  
  return ((p1 - p2)%m1)*scale  -- PERF: this branchless version is faster.
end

local function vvmodmul(A, i, x1, x2, x3, m)
  return tonumber(((A[i][1]*x1) % m + (A[i][2]*x2) % m + (A[i][3]*x3) % m) % m)
end

-- Skip ahead 2^k samples and returns last sample.
-- Notice n = 2^k, k >= 1.
function mrg_mt:_sampleahead2pow(k)
  local A1 = aheadA1[k]
  local A2 = aheadA2[k]
  local y11, y12, y13 = self._y11, self._y12, self._y13
  local y21, y22, y23 = self._y21, self._y22, self._y23
  self._y11 = vvmodmul(A1, 1, y11, y12, y13, m1)
  self._y12 = vvmodmul(A1, 2, y11, y12, y13, m1)
  self._y13 = vvmodmul(A1, 3, y11, y12, y13, m1)
  self._y21 = vvmodmul(A2, 1, y21, y22, y23, m2)
  self._y22 = vvmodmul(A2, 2, y21, y22, y23, m2)
  self._y23 = vvmodmul(A2, 3, y21, y22, y23, m2)
  -- PERF: this branchless version is faster:
  return ((self._y11 - self._y21)%m1)*scale
end

function mrg_mt:__tostring()
  return "sci.prng.mrg32k3a_ct"
       ..sarg(self._y11, self._y12, self._y13, 
              self._y21, self._y22, self._y23)
       
end

function mrg_mt:copy()
  return mrg_ct(self._y11, self._y12, self._y13, 
                self._y21, self._y22, self._y23)
end

mrg_ct = ffi.metatype("struct { double _y11, _y12, _y13, _y21, _y22, _y23; }",
                      mrg_mt)
M.mrg32k3a_ct = mrg_ct

function M.mrg32k3a()
  return mrg_ct(y0, y0, y0, y0, y0, y0)
end

return M