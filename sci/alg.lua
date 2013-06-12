--------------------------------------------------------------------------------
-- Dense vector and matrix algebra, main module.
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
local B    = require "sci.alg._base"
local cfg  = require "sci.alg.config"
require "sci.alg._vec" -- Add vector to B.
require "sci.alg._mat" -- Add matrix to B.

local M = {}

local err, chk = xsys.handlers("sci.alg")
local unroll = cfg.unroll

-- TODO: Configuration (perfect) check for aliasing.
-- TODO: Consider to add scl type (move out expressions with scalars as well).

M.idnode = B.idnode
M.toelwfunction = B.toelwfunction
M.dotprod = B.dotprod

--	Typeof ---------------------------------------------------------------------


M.typeof = xsys.cache(function(ct)
  local o = {}
  xsys.import(o, B.typeof_vec(ct))
  xsys.import(o, B.typeof_mat(ct))
  return o
end, "strong", function(x) return tonumber(ffi.typeof(x)) end)

xsys.import(M, M.typeof(ffi.typeof("double")))

-- Checks ----------------------------------------------------------------------
M.check = {}

function M.check.eqsize(x, y, what)
  if x:idnode().res == "v" then
    if not (#x == #y) then
      what = what or "vectors"
      err("range", 
          "equal size required for "..what..", sizes: "..(#x)..", "..(#y))
    end
  else
    if not (x:nrow() == y:nrow() and x:ncol() == y:ncol()) then
      what = what or "matrices"
      local xsize = x:nrow().."x"..x:ncol()
      local ysize = y:nrow().."x"..y:ncol()
      err("range", 
          "equal size required for "..what..", sizes: "..xsize..", "..ysize)
    end
  end
end

-- Functions -------------------------------------------------------------------

-- Example: slicer({2, 6}, {1, 3}, 1) == slicer({2, 6}, {1, 3}, {4, 4}).
-- Nil if {f, l} with l < f or if n and n <=0.
-- If number: k-th elements after the end of the last non-nil one.
function M.slicer(...)
  local r = {}
  local f, l = 0, 0
  for i=1,select("#", ...) do
    local el = select(i, ...)
    if type(el) == "table" then
      f, l = el[1], el[2]
    else
      f, l = l + 1, l + el
    end
    if f <= l then
      r[i] = "x:sub("..f..","..l..")"
    else
      r[i] = "nil"
    end
  end
  r = table.concat(r, ",")
  return xsys.compile("return function(x) return "..r.." end", "slicer")
end

local binopcode = [[
local f_d = {
# for d=1,unroll+1 do
[$(d)] = function(x)
  local v = $(init)
#   if d < unroll+1 then  
#     for i=1,d do
  v = v $(binop) x[$(i)]
#     end
#   else
  for i=1,#x do
    v = v $(binop) x[i]
  end
#   end
  return v
end,
# end
}
return function(x) -- Free check: #x > 0.
  return f_d[min(#x, $(unroll+1))](x)
end
]]

local binfcode = [[
local f_d = {
# for d=1,unroll+1 do
[$(d)] = function(x)
  local v = $(init)
#   if d < unroll+1 then  
#     for i=1,d do
  v = $(binf)(v, x[$(i)])
#     end
#   else
  for i=1,#x do
    v = $(binf)(v, x[i])
  end
#   end
  return v
end,
# end
}
return function(x) -- Free check: #x > 0.
  return f_d[min(#x, $(unroll+1))](x)
end
]]

local sumcode = xsys.preprocess(binopcode, { 
  binop = "+", 
  init = 0, 
  unroll = unroll
})
local prodcode = xsys.preprocess(binopcode, { 
  binop = "*", 
  init = 1, 
  unroll = unroll
})
local maxcode = xsys.preprocess(binfcode, { 
  binf = "max", 
  init = "-huge", 
  unroll = unroll
})
local mincode = xsys.preprocess(binfcode, { 
  binf = "min", 
  init = "huge", 
  unroll = unroll
})
local env = { min = math.min, max = math.max, huge = math.huge }
M.sum  = xsys.compile(sumcode,  "sum",  env)
M.prod = xsys.compile(prodcode, "prod", env)
M.min  = xsys.compile(mincode,  "min",  env)
M.max  = xsys.compile(maxcode,  "max",  env)

-- Element wise functions ------------------------------------------------------
for k,v in pairs(require "sci.math") do
  if type(v) == "function" then
    M["e"..k] = M.toelwfunction(v)
  end
end

return M
