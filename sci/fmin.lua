--------------------------------------------------------------------------------
-- Function minimization module.
--
-- Copyright (C) 2011-2012 Stefano Peluchetti. All rights reserved.
--
-- Features, documention and more: http://www.scilua.org .
--
-- This file is part of the SciLua library, which is released under the MIT 
-- license: full text in file LICENSE.TXT in the library's root folder.
--------------------------------------------------------------------------------

-- NOTE: Make sure that all error messages are still correct even when 
-- NOTE: -min(-f(x)) is used to compute max(f(x)).

local xsys = require "xsys"
local alg  = require "sci.alg"
local expr = require "sci._expr"

local M = {}

xsys.table.eval({
  "diffevol" 
}, function(x) xsys.import(M, require("sci.fmin._"..x)) end)

local boolgen = expr.boolgen
local err, chk = xsys.handlers("sci.fmin")

M._stop = {

newstopgen = boolgen,

period = function(p) return boolgen(function()
  local time = require "time"
  local start = time.nowutc()
  return function(xmin, fmin, x, fval)
    return time.nowutc() - start > p
  end
end) end,

iterations = function(n) return boolgen(function()
  chk(n >= 1, "constraint", "maximum iteration number = ", n, ", should be >=1")
  local count = 0
  return function(xmin, fmin, x, fval)
    count = count + 1
    return count >= n
  end
end) end,

frange = function(err) return boolgen(function()
  chk(err > 0, "constraint", "maximum error = ", err, ", should be >0")
  return function(xmin, fmin, x, fval)
    local fmax = alg.max(fval)
    return fmax - fmin <= err
  end
end) end,

xrange = function(err) return boolgen(function()
  chk(err > 0, "constraint", "maximum error = ", err, ", should be >0")
  return function(xmin, fmin, x, fval)
    for d=1,x:ncol() do
      local l, u = alg.min(x:col(d)), alg.max(x:col(d))
      if u - l > err then return false end
    end
    return true
  end
end) end,

}

xsys.import(M, M._stop)

return M