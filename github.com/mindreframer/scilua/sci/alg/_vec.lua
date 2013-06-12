--------------------------------------------------------------------------------
-- Dense vector and matrix algebra, vector module.
--
-- Copyright (C) 2011-2012 Stefano Peluchetti. All rights reserved.
--
-- Features, documention and more: http://www.scilua.org .
--
-- This file is part of the SciLua library, which is released under the MIT 
-- license: full text in file LICENSE.TXT in the library's root folder.
--------------------------------------------------------------------------------

local ffi  = require "ffi"
local cfg  = require "sci.alg.config"
local xsys = require "xsys"
local B    = require "sci.alg._base"

local err, chk = xsys.handlers("sci.alg")
local rcheck = cfg.rangecheck
local unroll = cfg.unroll
local int32_ct = ffi.new("int32_t")
local ceil = math.ceil

-- Specialization --------------------------------------------------------------

local setcode = [[
return function(lhs, rhs)
  $(dimcheck)
  local n = lhs._n
# for d=1,unroll do
  $(d == 1 and 'if' or 'elseif') n == $(d) then
#   for i=1,d do
  lhs[$(i)] = rhs[$(i)]
#   end
# end
  $(unroll > 0 and 'else')
    for i=1,n do
      lhs[i] = rhs[i]
    end
  $(unroll > 0 and 'end')
  return lhs
end
]]
local fillcode = [[
return function(lhs, rhs)
  local n = lhs._n
# for d=1,unroll do
  $(d == 1 and 'if' or 'elseif') n == $(d) then
#   for i=1,d do
  lhs[$(i)] = rhs
#   end
# end
  $(unroll > 0 and 'else')
    for i=1,n do
      lhs[i] = rhs
    end
  $(unroll > 0 and 'end')
  return lhs
end
]]
local gencode = [[
return function(lhs, rhs, ...)
  local n = lhs._n
# for d=1,unroll do
  $(d == 1 and 'if' or 'elseif') n == $(d) then
#   for i=1,d do
  lhs[$(i)] = rhs(...)
#   end
# end
  $(unroll > 0 and 'else')
    for i=1,n do
      lhs[i] = rhs(...)
    end
  $(unroll > 0 and 'end')
  return lhs
end
]]
local dotprodcode = [[
return function(lhs, rhs)
  $(dimcheck)
  local n = lhs._n
  local v = 0
# for d=1,unroll do
  $(d == 1 and 'if' or 'elseif') n == $(d) then
#   for i=1,d do
  v = v + lhs[$(i)]*rhs[$(i)]
#   end
# end
  $(unroll > 0 and 'else')
    for i=1,n do
      v = v + lhs[i]*rhs[i]
    end
  $(unroll > 0 and 'end')
  return v
end
]]

local function itermethod(code, name, dimcheck)
  return xsys.compile(code, name, { err = err }, 
    { unroll = unroll, dimcheck = dimcheck })
end

local dimcheck = rcheck and B.dimcheck.v.v() or  nil
local set     = itermethod(setcode,     "vectorset",  dimcheck)
local fill    = itermethod(fillcode,    "vectorfill")
local gen     = itermethod(gencode,     "vectorgen")
local dotprod = itermethod(dotprodcode, "dotprod",    dimcheck)
B.dotprod = dotprod

local function totable(self)
  local o = {}
  for i=1,self._n do 
    o[i] = self[i] 
  end
  return o
end

local function __len(self)
  return self._n
end

local function  __tostring(self)
  local o = {}
  for i=1,self._n do 
    o[i] = tostring(self[i]) 
  end
  return "{"..table.concat(o, ",").."}"
end

local function __gc(self)
  ffi.C.free(self._p1)
end

local methods = B.methods.v -- Idnode and __index dynamically created.

methods.ntbe = {}
methods.expr = {
  __len      = __len,
  __tostring = __tostring,
  totable    = totable,  
}
methods.view = {
  set  = set,
  fill = fill,
  gen  = gen,
}
xsys.import(methods.view, methods.expr)
methods.unde = {
  __gc = __gc,
}
xsys.import(methods.unde, methods.view)

-- Following depends on elct ---------------------------------------------------

B.typeof_vec = xsys.cache(function(elct)

local elptr_ct  = ffi.typeof("$*",	elct)

-- Owner (o), view (v), stided view (s).
local veco_mt, vecv_mt, vecs_mt = {}, {}, {}
local veco_ct, vecv_ct, vecs_ct
local vec

-- Idnode ----------------------------------------------------------------------
local veco_idnode = { -- Missing ct yet.
  res    = "v", 
  spec   = "unde", 
  mref   = {{ elptr_ct }},
  elct   = elct,
  env    = {},
  access = "self._p$(i)[k-1]",
}


local vecv_idnode = { -- Missing ct yet.
  res    = "v", 
  spec   = "view", 
  mref   = { { elptr_ct } },
  elct   = elct,
  env    = {},
  access = "self._p$(i)[k-1]",
}

local vecs_idnode = { -- Missing ct yet.
  res    = "v", 
  spec   = "view", 
  mref   = { { elptr_ct, int32_ct } },
  elct   = elct,
  env    = {},
  access = "self._p$(i)[self._s$(i)*(k-1)]",
}

function veco_mt:idnode()
  return veco_idnode
end
function vecv_mt:idnode()
  return vecv_idnode
end
function vecs_mt:idnode()
  return vecs_idnode
end

-- Indexing --------------------------------------------------------------------
-- Need to be defined here as method dispatch requires metatable (type dep).

for _,v in ipairs{ veco_mt, vecv_mt, vecs_mt } do
  v.__index    = B.accessmethod(B.indextemplate,    v:idnode(), v)
  v.__newindex = B.accessmethod(B.newindextemplate, v:idnode(), v)
end

-- Sub and stride --------------------------------------------------------------
-- Defined here as constructors are type dependent.

local subcheck = [[
if not (first <= last and 1 <= first and last <= self._n) then
  err("range",
      "out of range view: first="..first..", last="..last..", #="..self._n)
end
]]
local subcode = [[
local vec_ct -- Not yet set (debug.steupvalue later),
return function(self, first, last)
  $(subcheck)
  return vec_ct(self._p1 + first - 1, $(stride) last - first + 1)
end
]]
veco_mt.sub = xsys.compile(
  xsys.preprocess(subcode, { subcheck = rcheck and subcheck }),
  "vectorsub", { err = err }
)
vecv_mt.sub = veco_mt.sub
vecs_mt.sub = xsys.compile(
  xsys.preprocess(subcode, { subcheck = rcheck and subcheck, stride = "self._s1," }),
  "vectorsub", { err = err }
)

veco_mt.stride = function(self, onein)
  local size = ceil(self._n/onein) -- Always >= 1.
  return vecs_ct(self._p1, onein, size)
end
vecv_mt.stride = veco_mt.stride

vecs_mt.stride = function(self, onein)
  local size = ceil(self._n/onein) -- Always >= 1.
  return vecs_ct(self._p1, onein*self._s1, size)
end

-- Operators -------------------------------------------------------------------
B.setops(veco_mt, veco_idnode)
B.setops(vecv_mt, vecv_idnode)
B.setops(vecs_mt, vecs_idnode)

-- Methods ---------------------------------------------------------------------
B.setmethods(veco_mt, veco_idnode)
B.setmethods(vecv_mt, vecv_idnode)
B.setmethods(vecs_mt, vecs_idnode)

-- Copy ------------------------------------------------------------------------
veco_mt.copy = function(self)
  return vec(self)
end
vecv_mt.copy = veco_mt.copy
vecs_mt.copy = veco_mt.copy

-- Constructors ----------------------------------------------------------------
veco_ct = ffi.metatype(B.algct(veco_idnode), veco_mt)
vecv_ct = ffi.metatype(B.algct(vecv_idnode), vecv_mt)
vecs_ct = ffi.metatype(B.algct(vecs_idnode), vecs_mt)

veco_idnode.ct = veco_ct
vecv_idnode.ct = vecv_ct
vecs_idnode.ct = vecs_ct

assert(debug.setupvalue(veco_mt.sub, 1, vecv_ct) == "vec_ct")
assert(debug.setupvalue(vecv_mt.sub, 1, vecv_ct) == "vec_ct")
assert(debug.setupvalue(vecs_mt.sub, 1, vecs_ct) == "vec_ct")

local elsize = ffi.sizeof(elct)

vec = function(n, ...)
  local c = ...
  if type(n) ~= "number" then
    c = n
    n = #n
  end
  if not (n > 0) then
    err("constraint", "not positive sized vector: n="..n)
  end  
  local p = ffi.C.malloc(n*elsize)
  if not(p ~= nil) then
    err("nomem", "cannot allocate memory for vector of size n="..n)
  end
  local o = veco_ct(p, n)  
  -- Ok dynamic dispatch here, cost of allocation high anyway.
  local tc = type(c)
  if tc == "nil" then
    if select("#", ...) == 0 then
      ffi.fill(o._p1, n*elsize)
    end
    return o  
  elseif tc == "number" or tc == "boolean" or ffi.istype(elct, c) then 
    return o:fill(c)  -- Constant.
  elseif tc == "function" then 
    return o:gen(c)  -- Function.
  else 
    return o:set(c) -- Table array or v.
  end
end

return { 
  vec      = vec, 
  vec_ct   = veco_ct, 
  _vecv_ct = vecv_ct, 
  _vecs_ct = vecs_ct 
}

end, "strong", function(x) return tonumber(ffi.typeof(x)) end)
