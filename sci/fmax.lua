--------------------------------------------------------------------------------
-- Function maximization module.
--
-- Copyright (C) 2011-2012 Stefano Peluchetti. All rights reserved.
--
-- Features, documention and more: http://www.scilua.org .
--
-- This file is part of the SciLua library, which is released under the MIT 
-- license: full text in file LICENSE.TXT in the library's root folder.
--------------------------------------------------------------------------------

local fmin = require "sci.fmin"
local xsys = require "xsys"

local M = {}

local function minus(f)
  return function(...)
    return -f(...)
  end
end

-- Conventions:
-- arg[1]: function to be minimized
-- ret[1]: xmin
-- ret[2]: fmin
for algname,algf in pairs(fmin) do
  if type(algf) == "function" and not fmin._stop[algname] then
    M[algname] = function(f, ...)
      local mf = minus(f)
      local ret = { algf(mf, ...) }
      ret[2] = -ret[2]
      return unpack(ret)
    end
  end
end

xsys.import(M, fmin._stop)

return M