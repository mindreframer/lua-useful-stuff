--------------------------------------------------------------------------------
-- Shifted and scaled statistical distribution.
--
-- Copyright (C) 2011-2012 Stefano Peluchetti. All rights reserved.
--
-- Features, documention and more: http://www.scilua.org .
--
-- This file is part of the SciLua library, which is released under the MIT 
-- license: full text in file LICENSE.TXT in the library's root folder.
--------------------------------------------------------------------------------

local M = {}

local abs, log = math.abs, math.log

-- Dist, shift, scale = _d, _s, _m.
local ssd_mt = {}

function ssd_mt:range()
  local xl, xu = _d:range()
  return xl*self._m + self._s, xu*self._m + self._s
end

function ssd_mt:mean()
  return self._d:mean()*self._m + self._s
end

function ssd_mt:variance()
  return self._d:variance()*(self._m^2)
end

function ssd_mt:absmoment(mm)
  return self._d:absmoment(mm)*abs(self._m)^mm
end

function ssd_mt:pdf(x)
  return self._d:pdf((x - self._s)/self._m)/self._m
end

function ssd_mt:logpdf(x)
  return -log(self._m) + self._d:logpdf((x - self._s)/self._m)
end

function ssd_mt:sample(rng)
  return self._d:sample(rng)*self._m + self._s
end

M._ssd_mt = ssd_mt

return M