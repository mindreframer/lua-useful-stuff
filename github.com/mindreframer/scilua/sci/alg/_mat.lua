--------------------------------------------------------------------------------
-- Dense vector and matrix algebra, matrix module.
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
require "sci.alg._vec" -- Add vector to B.

local err, chk = xsys.handlers("sci.alg")
local rcheck = cfg.rangecheck
local unroll = cfg.unroll
local int32_ct = ffi.new("int32_t")

-- Specialization --------------------------------------------------------------

B.evalof = function(id)
  assert(id.spec == "ntbe")
  local lhsn = id.lhs.spec == "ntbe"
  local rhsn = id.rhs.spec == "ntbe"
  if not lhsn and not rhsn then
    if id.op == "*" then
      return meval
    elseif id.op == "^" then
      error("NYI")
    end
  elseif lhsn and not rhsn then
    error("NYI")
  elseif not lhsn and rhsn then
    error("NYI")
  end
end

local evalcode = [[
local f_d = {}
# for r=1,unroll do
f_d[$(r)] = {}
#   for c=1,unroll do
#     if r*c <= unroll then
f_d[$(r)][$(c)] = function(lhs, rhs)
#       for i=1,r do
#         for j=1,c do
  rhs[$(i)][$(j)] = lhs[$(i)][$(j)]
#         end
#       end
  return rhs
end
#     end
#   end
# end
return function(lhs, rhs) -- Lhs = in (self), rhs = out.
  $(dimcheck)
  if f_d[rhs._r] and f_d[rhs._r][rhs._c] then
    return f_d[rhs._r][rhs._c](lhs, rhs)
  else
    for i=1,rhs._r do
      for j=1,rhs._c do
        rhs[i][j] = lhs[i][j]
      end
    end
    return rhs
  end
end
]]
local fillcode = [[
local f_d = {}
# for r=1,unroll do
f_d[$(r)] = {}
#   for c=1,unroll do
#     if r*c <= unroll then
f_d[$(r)][$(c)] = function(lhs, rhs)
#       for i=1,r do
#         for j=1,c do
  lhs[$(i)][$(j)] = rhs
#         end
#       end
  return lhs
end
#     end
#   end
# end
return function(lhs, rhs)
  if f_d[lhs._r] and f_d[lhs._r][lhs._c] then
    return f_d[lhs._r][lhs._c](lhs, rhs)
  else
    for i=1,lhs._r do
      for j=1,lhs._c do
        lhs[i][j] = rhs
      end
    end
    return lhs
  end
end
]]
local gencode = [[
local f_d = {}
# for r=1,unroll do
f_d[$(r)] = {}
#   for c=1,unroll do
#     if r*c <= unroll then
f_d[$(r)][$(c)] = function(lhs, rhs, ...)
#       for i=1,r do
#         for j=1,c do
  lhs[$(i)][$(j)] = rhs(...)
#         end
#       end
  return lhs
end
#     end
#   end
# end
return function(lhs, rhs, ...)
  if f_d[lhs._r] and f_d[lhs._r][lhs._c] then
    return f_d[lhs._r][lhs._c](lhs, rhs, ...)
  else
    for i=1,lhs._r do
      for j=1,lhs._c do
        lhs[i][j] = rhs(...)
      end
    end
    return lhs
  end
end
]]
local mevalcode = [[
local f_d = {}
# for r=1,unroll do
f_d[$(r)] = {}
#   for c=1,unroll do
#     if r*c <= unroll then
f_d[$(r)][$(c)] = function(lhs, rhs)
#       for i=1,r do
#         for j=1,c do
  rhs[$(i)][$(j)] = dotprod(lhs._p1:row($(i)), lhs._p2:col($(j)))
#         end
#       end
  return rhs
end
#     end
#   end
# end
return function(lhs, rhs) -- Lhs = in (self), rhs = out.
  $(dimcheck)
  if f_d[lhs._r] and f_d[lhs._r][lhs._c] then
    return f_d[lhs._r][lhs._c](lhs, rhs)
  else
    local ni = lhs._p1._c
    for i=1,lhs._r do
      for j=1,lhs._c do
        local v = 0
        for k=1,ni do
          v = v + lhs._p1[i][k] * lhs._p2[k][j]
        end
        rhs[i][j] = v
      end
    end
    -- return rhs
  end
end
]]

local function itermethod(code, name, dimcheck)
  return xsys.compile(code, name, { dotprod = B.dotprod, err = err },
    { unroll = unroll, dimcheck = dimcheck })
end

local dimcheck = rcheck and B.dimcheck.m.m() or nil
local eval  = itermethod(evalcode,  "matrixeval",    dimcheck)
local fill  = itermethod(fillcode,  "matrixfill")
local gen   = itermethod(gencode,   "matrixgen")
local ta2d  = itermethod(evalcode,  "matrixta2d")
local meval = itermethod(mevalcode, "matrixmuleval", dimcheck)

local set = rcheck and function(self, x)  
  if not (self._r == x._r and self._c == x._c) then
    err("range", "equal size required for matrices, sizes: "
      ..self._r.."x"..self._c..", "..x._r.."x"..x._c)
  end
  return x:eval(self)
end
or function(self, x)
  return x:eval(self)
end

local function nrow(self)
  return self._r
end

local function ncol(self)
  return self._c
end

local function totable(self)
  local o = {}
  for i=1,self._r do 
    o[i] = self[i]:totable() 
  end
  return o
end

local function __tostring(self)
  local o = {}
  for i=1,self._r do 
    o[i] = tostring(self[i]) 
  end
  return "{"..table.concat(o, ",").."}"
end

local function __gc(self)
  ffi.C.free(self._p1)
end

local methods = B.methods.m

methods.ntbe = {}
methods.expr = {
  nrow       = nrow,
  ncol       = ncol,
  __tostring = __tostring,
  totable    = totable,
  eval       = eval,
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

-- Evalof ----------------------------------------------------------------------
B.evalof = function(id)
  return meval
end

-- evalof["^"] = function(id)
-- end

-- Following depends on elct ---------------------------------------------------

B.typeof_mat = xsys.cache(function(elct)

local elptr_ct = ffi.typeof("$*",	elct)

local algv = B.typeof_vec(elct)
local vecv_ct = algv._vecv_ct
local vecs_ct = algv._vecs_ct

local mato_mt, matv_mt = {}, {}
local mato_ct, matv_ct

local mato_idnode = { -- Missing ct yet.
  res    = "m", 
  spec   = "unde", 
  mref   = { { elptr_ct, int32_ct } },
  elct   = elct,
  env    = { vecv_ct = vecv_ct },
  access = "vecv_ct(self._p$(i)+self._s$(i)*(k-1),self._c)"
}

local matv_idnode = { -- Missing ct yet.
  res    = "m", 
  spec   = "view", 
  mref   = { { elptr_ct, int32_ct } },
  elct   = elct,
  env    = { vecv_ct = vecv_ct },
  access = "vecv_ct(self._p$(i)+self._s$(i)*(k-1),self._c)"
}

function mato_mt:idnode()
  return mato_idnode
end
function matv_mt:idnode()
  return matv_idnode
end

-- Indexing --------------------------------------------------------------------
-- Need to be defined here as method dispatch requires metatable (type dep).

for _,m in ipairs{ mato_mt, matv_mt } do
  m.__index  = B.accessmethod(B.indextemplate, m:idnode(), m)
end

-- Row and col -----------------------------------------------------------------
-- Defined here as constructors are type dependent.
-- Cannot use pre-processor as vecv_ct and vecs_ct are nil upvalues at this
-- point and cdata object metatable cannot be modified after ffi.metatype.

-- TODO: Implement rows(first, last) and cols(first, last).

mato_mt.row = mato_mt.__index

mato_mt.col = rcheck and function(self, c)
  if not (1 <= c and c <= self._c) then
    err("range", "out of range indexing: k="..c..", ncol="..self._c)
  end
  return vecs_ct(self._p1 + c - 1, self._c, self._r)
end
or function(self, c)
  return vecs_ct(self._p1 + c - 1, self._c, self._r)
end

-- Operators -------------------------------------------------------------------
B.setops(mato_mt, mato_idnode)
B.setops(matv_mt, matv_idnode)

-- Methods ---------------------------------------------------------------------
B.setmethods(mato_mt, mato_idnode)
B.setmethods(matv_mt, matv_idnode)

-- Copy ------------------------------------------------------------------------
mato_mt.copy = function(self)
  return mat(self)
end
matv_mt.copy = mato_mt.copy

-- Constructors ----------------------------------------------------------------
mato_ct = ffi.metatype(B.algct(mato_idnode), mato_mt)
matv_ct = ffi.metatype(B.algct(matv_idnode), matv_mt)

mato_idnode.ct = mato_ct
matv_idnode.ct = matv_ct

local elsize = ffi.sizeof(elct)

-- TODO: efficient from table init.
local function mat(nrow, ncol, ...)
  local c = ...
  if type(nrow) ~= "number" then
    c = nrow
    if type(c) == "table" then
      nrow = #c
      ncol = #c[1]
    else
      nrow = c:nrow()
      ncol = c:ncol()
    end      
  end
  if not (nrow > 0 and ncol > 0) then
    err("constraint", 
        "not positive sized matrix of dimension "..nrow.."x"..ncol)
  end
  
  local n = nrow*ncol
  local p = ffi.C.malloc(n*elsize)
  if not(p ~= nil) then
    err("nomem", "cannot allocate memory for matrix of "..n.." elements")
  end
  local o = mato_ct(p, ncol, nrow, ncol)
  
  -- Ok dynamic dispatch here, cost of allocation high anyway.
  local tc = type(c)
  if tc == "nil" then
    if select("#", ...) == 0 then
      ffi.fill(o._p1, n*elsize)
    end
    return o
  elseif tc == "number" or tc == "boolean" or ffi.istype(elct, c) then 
    return o:fill(c) -- Constant.
  elseif tc == "function" then 
    return o:gen(c) -- Function.
  elseif tc == "table" then
    return ta2d(c, o)
  else
    return o:set(c) -- M.
  end
  
  return o
end

return { mat = mat, mato_ct = mato_ct }

end, "strong", function(x) return tonumber(ffi.typeof(x)) end)
