--------------------------------------------------------------------------------
-- Differential evolution algorithm module.
--
-- Copyright (C) 2011-2012 Stefano Peluchetti. All rights reserved.
--
-- Features, documention and more: http://www.scilua.org .
--
-- This file is part of the SciLua library, which is released under the MIT 
-- license: full text in file LICENSE.TXT in the library's root folder.
--------------------------------------------------------------------------------

local xsys = require "xsys"
local alg  = require "sci.alg"
local prng = require "sci.prng"
local dist = require "sci.dist"

-- TODO: Fix sci.fmin being reported in sci.fmax functions.

local err, chk = xsys.handlers("sci.fmin")
local min, max, abs, int,   ceil = xsys.from(math,
     "min, max, abs, floor, ceil")

-- PERF: better to just do a single check, condition is true with high
-- PERF: probability and sampling uniform not expensive.
local function distinctj(j, sd, r)
  local j1, j2, j3 = int(sd:sample(r)), int(sd:sample(r)), int(sd:sample(r))
  while min(abs(j1 - j2), abs(j1 - j3), abs(j2 - j3), abs(j1 - j)) == 0 do
    j1 = int(sd:sample(r))
    j2 = int(sd:sample(r))
    j3 = int(sd:sample(r))
  end
  return j1, j2, j3
end

local function updatemin(xmin, fmin, xval, fval)
  if fval < fmin then
    return xval, fval
  else
    return xmin, fmin
  end
end

local boundf = {
  reflect = function(x, xl, xu)
    local b = max(min(x, xu), xl)
    -- Value of b must be xl if x < xl, xu if x > xu and x otherwise.
    return 2*b - x
  end,
  absorb = function(x, xl, xu)
    return max(min(x, xu), xl)
  end,
  no = function(x, xl, xu)
    return x
  end
}

-- TODO: Introduce integer distribution via uniform(vec).
-- For integer from a to b use u(a, b+1) and floor it --> index of the vec!

-- TODO: maxinitsample >= NP check.

-- Options:
-- (xval and fval) or (xlower and xupper and NP)
-- stop
-- o: rng
-- o: F (0, 2]
-- o: CR (0, 1]
-- TODO: o: strategy "des"
-- o: maxinitsample
-- o: bounds "reflect", "absorb", "no"
local function diffevol(f, o)
  chk((o.xval and o.fval) or (o.xlower and o.xupper and o.NP), "constraint",
      "(xval and fval) or (xlower and xupper and NP) required")
  chk(o.stop, "constraint", "stop required")
    
  local xl    = o.xlower
  local xu    = o.xupper
  local NP    = o.NP or o.xval:nrow()
  local stop  = o.stop()
  local rng   = o.rng or prng.std()
  local F	    = o.F or 1
  local CR    = o.CR or 0.75
  -- local evol  = evolf[o.strategy or "des"]
  local maxin = o.maxinitsample or 100*NP -- At least 1% in support zone.
  local bound = boundf[o.bounds or "reflect"]
  local dim   = o.xlower and #o.xlower or o.xval:ncol()
  
  chk(NP >= 4,            "constraint", "NP:", NP, ", required >= 4")
  chk(0 < F and F <= 2,   "constraint", "F:",  F,  ", required 0<F<=2")
  chk(0 < CR and CR <= 1, "constraint", "CR:", CR, ", required 0<CR<=1")
  chk(dim >= 1,           "constraint", "dimension:", dim, 
      ", required dimension>=1")
  
  local popd = dist.mduniform(o.xlower, o.xupper)
  local idxd = dist.uniform(1, NP + 1)
  local movd = dist.uniform(1, dim + 1)
  local u01d = dist.uniform(0, 1)
  local xval = alg.mat(NP, dim)
  local fval = alg.vec(NP)
  local fmin = math.huge
  local xmin
  local u = alg.mat(NP, dim)
  
  if o.xval then -- Population has priority.
    xval:set(o.xval)
    fval:set(o.fval) -- In case of no bounds infinite values are allowed.
    for j=1,NP do
      xmin, fmin = updatemin(xmin, fmin, xval:row(j), fval[j])
    end
  else
    local iter = 0
    for j=1,NP do
      repeat
  iter = iter + 1
  chk(iter <= maxin, "error", "maxinitsample=", maxin, " exceeded")
  popd:sample(rng, xval:row(j))
  fval[j] = f(xval:row(j))
      until fval[j] < math.huge
      --print(xval:row(j), fval[j], fmin)
      xmin, fmin = updatemin(xmin, fmin, xval:row(j), fval[j])
    end
  end
  
  while not stop(xmin, fmin, xval, fval) do
    for j=1,NP do
      -- Sample the three otehr distrinct indexes of population,
      local j1, j2, j3 = distinctj(j, idxd, rng)
      
      -- Mutation v, faster with expression than with vector!
      local v = xval:row(j1) + (xval:row(j2) - xval:row(j3))*F
      
      -- Crossover —> proposed u.  
      local kmove = int(movd:sample(rng))
      for k=1,dim do --> #unroll(10)
  -- Move if z == 0.
  local z = min(abs(k - kmove), ceil(u01d:sample(rng) - CR))
  u[j][k] = (1 - z)*v[k] + z*xval[j][k]
  -- Bounds.
  u[j][k] = bound(u[j][k], xl[k], xu[k])   
      end
    end
    
      -- Selection.
    for j=1,NP do
      local fuj = f(u:row(j))
      if fuj < fval[j] then -- It's an improvement --> select.
  fval[j] = fuj
  xval:row(j):set(u:row(j))
  xmin, fmin = updatemin(xmin, fmin, xval:row(j), fuj)
      end
    end
  end
  
  return xmin:copy(), fmin, xval, fval
end

return { diffevol = diffevol }