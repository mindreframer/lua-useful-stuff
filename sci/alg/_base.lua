--------------------------------------------------------------------------------
-- Dense vector and matrix algebra, base module.
--
-- Copyright (C) 2011-2012 Stefano Peluchetti. All rights reserved.
--
-- Features, documention and more: http://www.scilua.org .
--
-- This file is part of the SciLua library, which is released under the MIT 
-- license: full text in file LICENSE.TXT in the library's root folder.
--------------------------------------------------------------------------------

-- TODO: Memory pool for temps in expressions (and for all algebra objects 
--       when __gc + sinking supported).
-- TODO: Multiplication and power operators for matrices.
-- TODO: Aggregation of vectors and matrices (to data or expression?)
-- TODO: Read functions should return array which is later concatenated.
-- PERF: Set/get functions do not seem to pay off, removed for now.
-- WARN: If access oprator in matrix is changed to return pointer the ordering
-- WARN: operators will return an incorrect results if not changed as well!

local ffi  = require "ffi"
local cfg  = require "sci.alg.config"
local xsys = require "xsys"

local M = {}

local err, chk = xsys.handlers("sci.alg")
local rcheck = cfg.rangecheck
local maxctnum = cfg.maxctnum
local unroll = cfg.unroll
local double_ct = ffi.typeof("double")
local double_ctnum = tonumber(double_ct)
local typeof = ffi.typeof

ffi.cdef[[
void *malloc(size_t n);
void free(void *p);
]]

local auto_mt = { __index = function(self, k)
    self[k] = {}
    return self[k]
  end 
}

-- Concepts --------------------------------------------------------------------

-- Each object has 1 *res* (what it is meant to represent):
-- *v*: a kind of vector (algebra object)
-- *m*: a kind of matrix (algebra object)
-- *s*: a kind of scalar (not algebra object)

-- Each object has 1 *spec*:
-- *unde*: the actual owner of the data: s, *vec* and *mat* and only these.
-- *view*: a read/write view on the a underlying, same functionality of 
--         underlying res but does not own the data
-- *expr*: a read only epxression which has reference semantics on the elements
--         that compose it, same read only funcionality of its res
-- *ntbe*: a read only expression featuring limited functionality: only
--         *:evalinto(y)* and *:copy()* which both forces the evaluation. No 
--         indexing; used when temporaries are needed because of aliasing or/and
--         operations that the expression represents.

-- Strided, triangular, diagonal, symmetric, non-dense are implementation 
-- details. 

-- Each algebra object contains:
-- *mref* (members reference data), x is the x-th mref: 
--   _px pointers (+ opt _sx stride) for underlying data
--   _px non-pointers for scalar and ntbe expressions
-- *mdim* (memebrs dimension data):
--   _n     for v
--   _r, _c for m

-- Each object (even not-algebra) has an associated id node (via idnode(obj))
-- containing:

-- res     : see above
-- spec    : see above 
-- mref    : see above, info stored as a table of tables where each row contains 
--           1 or 2 ctype elements: first element correspond to pointer to 
--           underlying data or scalar or ntbe  expression, second element (when 
--           present) is the stride related to the unde pointed from the first 
--           element (which must be of pointer type)
-- elct    : element ctype, needed for size of element
-- ct      : ctype of the non-owner object corresponding to the object, needed
--           for ntbe
-- env     : environment for the expression (needed for function preop)

-- [op]    : unary and binary operators ('-', '^', ...) or a unique string
--           for a function obtained by calling ftoname(function)
-- TODO: [arg]   : arguments (child nodes) for op.

-- [access]: string to be preprocessed to obtain code for accessig the k-th 
--           element of the algebra object (ntbe expressions excluded) assuming 
--           that the mref corresponding to this is node are inside a struct 
--           with i-1 mref elements before.

-- Core functions --------------------------------------------------------------

local function getid(x)
  return x.idnode
end

-- True if x is any algebra object (i.e. res is v or m).
-- Slow: don't use in performance critical parts.
local function isalg(x)
  if type(x) ~= "cdata" then 
    return false
  else
    local ok, found = pcall(getid, x)
    return ok and type(found) == "function"
  end
end

-- Return id node for object x assuming non cdata types are scalars of 
-- ctype double.
-- Slow: don't use in performance critical parts.
local function idnode(x)
  if isalg(x) then 
    return x:idnode() 
  else
    local ct = type(x) == "cdata" and ffi.typeof(x) or double_ct
    return {
      res    = "s",
      spec   = "unde",
      mref   = { { ct } },
      elct   = ct,
      ct     = ct,
      env    = {},
      access = "self._p$(i)",
    }
  end
end
M.idnode = idnode

-- Algebra objects constructor functions ---------------------------------------

-- Return ctype for the anonymous struct for a generic algebra object which is
-- composed of the ctypes in mref plus 1 or 2 dimenision variables.
-- Supports ntbe expressions as well and vectors and matrices.
function M.algct(id)
  assert(id.res == "v" or id.res == "m")
  local mref = id.mref
  local dim = id.res == "m" and 2 or 1
  local o = { "struct {" }
  local acts = {}
  for i=1,#mref do
    if #mref[i] == 1 then
      o[#o + 1] = "$ _p"..i..";"
      table.insert(acts, mref[i][1])
    elseif #mref[i] == 2 then
      o[#o + 1] = "$ _p"..i.."; $ _s"..i..";"
      table.insert(acts, mref[i][1])
      table.insert(acts, mref[i][2])
    else
      error("malformed mref of size "..(#mref[i]))
    end
  end
  o[#o + 1] = dim == 1 and "int32_t _n; \n}" or "int32_t _r;\nint32_t _c; \n}"
  local struct = table.concat(o, "\n")
  -- print(struct)
  return ffi.typeof(struct, unpack(acts))
end

-- Return code used to read all the non dimensional data belonging to a variable 
-- named varname which refers to x (a scalar or any of the algebra objects).
-- Examples: 
-- 'myvar._p1, myvar._p2, myvar._s2' (not ntbe expression, vectors, ...)
-- 'myvar' (scalar)
-- 'myvar._p1, myvar._p2' (ntbe expression).
-- It's used when constructing an expression (the components of the lhs and rhs 
-- or of the ohs of the expression needs to be passed to the new expression 
-- constrcutor).
local function mrefread(id, varname)
  if id.res == "s" then return varname end -- It's a scalar.
  local mref = id.mref
  local o = {}
  for i=1,#mref do
    if #mref[i] == 1 then
      o[#o + 1] = varname.."._p"..i
    elseif #mref[i] == 2 then
      o[#o + 1] = varname.."._p"..i
      o[#o + 1] = varname.."._s"..i
    else
      error("malformed mref of size "..(#mref[i]))
    end
  end
  local data = table.concat(o, ",")
  return data
end
M.mrefread = mrefread

-- Return code used to read all the dimensional data belonging to a variable 
-- named varname which refers to x which must be any algebra object.
-- Examples: 
-- 'myvar._n' (vector expression, vector)
-- 'myvar._r, myvar._c' (maxtrix expression, matrix)
-- It's used when constructing an expression (the components of the lhs and rhs 
-- or of the ohs of the expression needs to be passed to the new expression 
-- constrcutor). 
local function mdimread(id, varname)
  if id.res == "v" then
    return varname.."._n"
  elseif id.res == "m" then
    return varname.."._r, "..varname.."._c"
  else
    error("scalar is dimensionless")
  end
end

-- T0D0: Templated.
-- T0D0: Remove copy ctor trick when nested structs JIT-ed.
-- Returns constructor function for any algebra ctype alge_ct.
local function algconstructor(alge_ct, vars, data, check, pre)
  check = check or ""
  pre   = pre   or ""
  check = type(check) == "table" and "" or check
  local s = "local o = alge_ct() return function("..vars..") "
          ..check
          ..pre
          .." return alge_ct("..data..") end"
  return xsys.compile(s, "algct", { alge_ct = alge_ct, err = err })
end

-- Specialization functions ----------------------------------------------------

-- Defines results of binary operations (and supported operations):
local binopres = setmetatable({}, auto_mt) -- [lhs res][rhs res]
binopres.v.v = "v"
binopres.v.s = "v"
binopres.s.v = "v"
binopres.m.m = "m"
binopres.m.s = "m"
binopres.s.m = "m"

-- Code for checking correctness of dimensions.
local dimcheck = setmetatable({}, auto_mt) -- [lhs res][rhs res]
dimcheck.v.v = function() return [[
if not (lhs._n == #rhs) then -- Allows table on rhs.
  err("range", 
      "equal size required for vectors, sizes: "..lhs._n..", "..(#rhs))
end
]] 
end
dimcheck.v.s = function() return "" end
dimcheck.s.v = function() return "" end
dimcheck.m.m = function(op)
  if op == "*" then return [[
if not (lhs._c == rhs._r) then
  local lhssize = lhs._r.."x"..lhs._c
  local rhssize = rhs._r.."x"..rhs._c
  err("range", 
      "incompatible product of matrices, sizes: "..lhssize..", "..rhssize)
end
]]
  else return [[
if not (lhs._r == rhs._r and lhs._c == rhs._c) then
  local lhssize = lhs._r.."x"..lhs._c
  local rhssize = rhs._r.."x"..rhs._c
  err("range", 
      "equal size required for matrices, sizes: "..lhssize..", "..rhssize)
end
]]
  end
end
dimcheck.m.s = function(op)
  if op == "^" then return [[
if not (lhs._r == lhs._c) then
  err("range", 
      "square matrix required for ^ operator, size: "..lhs._r.."x"..lhs._c)
end
]]
  else return ""
  end
end
dimcheck.s.m = function() return "" end
M.dimcheck = dimcheck

-- Code for checking in range indexing:
local accesscheck = {} -- [res]
accesscheck.v = [[
if not(1 <= k and k <= self._n) then
  err("range", "out of range indexing: k="..k..", #="..self._n)
end
]]
accesscheck.m = [[
if not(1 <= k and k <= self._r) then
  err("range", "out of range indexing: k="..k..", nrow="..self._r)
end
]] 

-- All possible methods for 
local methods = setmetatable({}, auto_mt) -- [res][spec]
M.methods = methods

-- Access ----------------------------------------------------------------------

-- Index and newindex are user-callable read/write.
-- Compiled with accessmethod.
M.indextemplate = [[
return function(self, k)
  if type(k) == "number" then
    $(rcheck)
    return $(access)
  else
    return mt[k]
  end
end
]]

M.newindextemplate = [[
return function(self, k, v)
  if type(k) == "number" then
    $(rcheck)
    $(access) = v
  else
    err("misuse", "cannot set not numeric key "..k)
  end
end
]]

local function accessfrom(code, i)
  local s = xsys.preprocess(code, { i = i })
  return s
end

-- Compile a function to read/write data based on the access template, 
-- the string for the actual access, the metatable and anything else which may
-- be put into the environment.
function M.accessmethod(accesstemplate, id, mt)
  assert(id.spec ~= "ntbe")
  local s = xsys.preprocess(accesstemplate, {
    rcheck = rcheck and accesscheck[id.res] or nil,
    access = accessfrom(id.access, 1),
  })
  local e = { type = type, err = err, mt = mt }
  xsys.import(e, id.env)
  return xsys.compile(s, "accessor", e)
end

-- Expr or ntbe id node -> res.
local function resof(id)
  assert(id.op)
  assert(not id.res)
  if not id.ohs then -- Binary operator case.
    local res = binopres[id.lhs.res][id.rhs.res]
    if type(res) ~= "string" then
      err("misuse",
          "unsupported binary operation: "..id.lhs.res..id.op..id.rhs.res)
    end
    return res
  else -- Unary operator case.
    return id.ohs.res
  end
end

-- Only m*m and m^s are not element-wise operations:
local function isnotelw(id)
  if id.res ~= "m" then
    return false
  else
    if id.op == "*" then
      return id.lhs.res == "m" and id.rhs.res == "m"
    elseif id.op == "^" then
      return id.lhs.res == "m" and id.rhs.res == "s"
    else
      return false
    end
  end
end

-- Op id node -> spec.
local function specof(id)
  assert(id.op)
  assert(not id.spec)
  if id.ohs then 
    return id.ohs.spec == "ntbe" and "ntbe" or "expr"
  else
    if id.lhs.spec == "ntbe" or id.rhs.spec == "ntbe" then
      return "ntbe"
    else
      return isnotelw(id) and "ntbe" or "expr"
    end
  end
end

-- Expr or ntbe id node -> mref.
local function mrefof(id)
  assert(id.op)
  assert(id.spec)
  assert(not id.mref)
  if id.ohs then
    return id.ohs.mref
  else
    if id.spec ~= "ntbe" then
      return xsys.table.join(id.lhs.mref, id.rhs.mref)
    else
      return { { id.lhs.ct }, { id.rhs.ct } }
    end
  end
end

-- Op id node -> access (may be nil).
local function accessof(id)
  assert(id.op)
  assert(id.spec)
  assert(not id.access)
  if id.spec == "ntbe" then return nil end
  if id.ohs then 
    return id.op.."("..id.ohs.access..")"
  else
    return "("..id.lhs.access..")"
         ..id.op
         .."("..id.rhs.access:gsub("%(i", "%(i+"..tostring(#id.lhs.mref))..")"
  end
end

local function mrefreadof(id)
  assert(id.op)
  assert(id.spec)
  if id.ohs then
    return id.spec ~= "ntbe" and mrefread(id.ohs, "ohs").."," or "ohs,"
  else  
    return id.spec ~= "ntbe" 
      and mrefread(id.lhs, "lhs")..","..mrefread(id.rhs, "rhs")..","
      --  TODO: put back when nested structs ctors JIT-ed.
      or  "o" -- "lhs,rhs,"
  end
end

local function mdimreadof(id)
  assert(id.op)
  assert(id.res)
  assert(id.spec)
  if id.ohs then
    return mdimread(id.ohs, "ohs")
  else  
    if id.spec == "ntbe" then
      -- TODO: put back when nested structs ctors JIT-ed.
      return "" -- "lhs._r,rhs._c"
    else
      return id.lhs.res ~= "s" and mdimread(id.lhs, "lhs")
                               or  mdimread(id.rhs, "rhs")
    end
  end
end

local function dimcheckof(id)
  assert(id.op)
  assert(id.res)
  assert(id.spec)
  if id.ohs then
    return nil
  else
    return dimcheck[id.lhs.res][id.rhs.res](id.op)
  end
end

-- TODO: remove when nested structs ctors JIT-ed.
local function preof(id)
  if id.ohs then
    return "o._p1=ohs;o._r=ohs._r;o._c=ohs._c;"
  else
    if id.spec == "ntbe" then
      return "o._p1=lhs;o._p2=rhs;o._r=lhs._r;o._c=rhs._c;"
    else
      return ""
    end
  end
end

-- local evalof = {}
-- M.evalof = evalof

-- Operators -------------------------------------------------------------------
-- TODO: Extend preop to work with (limited number of) multiple arguments.

-- TODO: early termination, unrolling performance impact? 
local ordopcode = [[
  return function(lhs, rhs)
  $(rcheck)
  local v = true
  for i=1,$(dim) do
    if not ($(cond)) then v = false end
  end
    return v
  end
]]

local function ordopcompile(rcheck, dim, cond)
  return xsys.compile(ordopcode, "algcomparison", { err = err }, 
    { rcheck = rcheck, dim = dim, cond = cond })
end

local ordop_t = {}
for _,op in ipairs { "==", "<", "<=" } do
  ordop_t[op] = setmetatable({}, auto_mt)
  ordop_t[op].v.v = ordopcompile(dimcheck.v.v(), "lhs._n", 
    "lhs[i]"..op.."rhs[i]")
  ordop_t[op].v.s = ordopcompile(dimcheck.v.s(), "lhs._n", 
    "lhs[i]"..op.."rhs")
  ordop_t[op].s.v = ordopcompile(dimcheck.s.v(), "rhs._n", 
    "lhs"..op.."rhs[i]")
  ordop_t[op].m.m = ordopcompile(dimcheck.m.m(), "lhs._r",
    "lhs[i]"..op.."rhs[i]")
  ordop_t[op].m.s = ordopcompile(dimcheck.m.s(), "lhs._r",
    "lhs[i]"..op.."rhs")
  ordop_t[op].s.m = ordopcompile(dimcheck.s.m(), "rhs._r",
    "lhs"..op.."rhs[i]")
end

local ordop = function(op)
  local dispatch = setmetatable({}, { __index = function(self, ctnum)
    return function(lhs, rhs)
      local lhsr = idnode(lhs).res
      local rhsr = idnode(rhs).res
      local ordop_f = ordop_t[op][lhsr][rhsr]
      if not (type(ordop_f) == "function") then
  err("misuse", "cannot compare "..lhsr.." with "..rhsr)
      end
      self[ctnum] = ordop_f
      return ordop_f(lhs, rhs)
    end
  end })
  return function(lhs, rhs)
    local rhst = type(rhs) == "cdata" and tonumber(typeof(rhs)) or double_ctnum
    local lhst = type(lhs) == "cdata" and tonumber(typeof(lhs)) or double_ctnum
    return dispatch[lhst + rhst*maxctnum](lhs, rhs)
  end
end

local __eq = ordop("==")
local __lt = ordop("<")
local __le = ordop("<=")

local __add, __sub, __mul, __div, __pow, __mod
local __unm

-- Set the operators for any algebra object.
local function setops(mt, id)
  -- Arith binary:
  mt.__add = __add
  mt.__sub = __sub
  mt.__mul = __mul
  mt.__div = __div
  mt.__pow = __pow
  mt.__mod = __mod
  -- Arith unary:
  mt.__unm = __unm
  -- Order binary:
  mt.__eq = __eq
  mt.__lt = __lt
  mt.__le = __le
end
M.setops = setops

-- Set the metamethods for the expression.
local function setmethods(mt, id)
  mt.idnode = function(self) return id end
  if id.spec ~= "ntbe" then
    mt.__index = M.accessmethod(M.indextemplate, id, mt)
  else
    mt.__index = mt
    mt.eval = M.evalof(id)
  end
  xsys.import(mt, methods[id.res][id.spec])
end
M.setmethods = setmethods

-- Returns unique id string for any given function, uniquness asserted in 
-- envmerge.
local function ftoname(f)
  if type(f) == "string" then return f end
  local s = "f_"..tostring(f):sub(11):gsub("#", "_")
  return s
end

-- Merge two envs making sure that if two keys are the same then the same holds
-- for the value, i.e. it's ok to merge them.
local function envmerge(x, y)
  local o = {}
  for k,v in pairs(x) do 
    o[k] = v 
  end
  for k,v in pairs(y) do
    if o[k] then 
      assert(o[k] == v)
    else
      o[k] = v
    end
  end
  return o
end

local binop = function(op)
  local dispatch = setmetatable({}, { __index = function(self, ctnum)  
    return function(lhs, rhs) 
      local expr_mt, alge_ct = {}
      local idlhs, idrhs = idnode(lhs), idnode(rhs)      
      local id = {
        env  = envmerge(idlhs.env, idrhs.env),
        op   = op,
        elct = idlhs.elct,
        lhs  = idlhs, 
        rhs  = idrhs
      }
      id.res    = resof(id)
      id.spec   = specof(id)
      id.mref   = mrefof(id)
      id.access = accessof(id)
 
      setmethods(expr_mt, id)
      setops(expr_mt, id)
     
      local expr_t = M.algct(id)
      alge_ct = ffi.metatype(expr_t, expr_mt)
      assert(tonumber(alge_ct) < maxctnum)
      id.ct = alge_ct
      
      local mref  = mrefreadof(id)
      local mdim  = mdimreadof(id)
      local check = dimcheckof(id)
      local pre = preof(id) -- TODO: remove when nested struct ctors JIT-ed.
      local expr_f = algconstructor(alge_ct, "lhs,rhs", mref..mdim, check, pre)
      
      self[ctnum] = expr_f
      return expr_f(lhs, rhs)
    end
  end })
  
  return function(lhs, rhs)
    local rhst = type(rhs) == "cdata" and tonumber(typeof(rhs)) or double_ctnum
    local lhst = type(lhs) == "cdata" and tonumber(typeof(lhs)) or double_ctnum
    return dispatch[lhst + rhst*maxctnum](lhs, rhs)
  end
end

local preop = function(op)
  local dispatch = setmetatable({}, { __index = function(self, ctnum)  
    return function(ohs)
      local expr_mt, alge_ct = {}
      local idohs = ohs:idnode() -- Cannot be scalar.
      local fname = ftoname(op)      
      local id = {
        env  = op == "-" and idohs.env 
                         or  envmerge({ [fname] = op }, idohs.env),
        op   = fname,
        elct = idohs.elct,
        ohs  = idohs 
      }
      id.res    = resof(id)
      id.spec   = specof(id)
      id.mref   = mrefof(id)
      id.access = accessof(id)

      setmethods(expr_mt, id)
      setops(expr_mt, id)
      
      local expr_t = M.algct(id)
      alge_ct = ffi.metatype(expr_t, expr_mt)
      assert(tonumber(alge_ct) < maxctnum)
      id.ct = alge_ct
      
      local mref  = mrefreadof(id)
      local mdim  = mdimreadof(id)
      local check = dimcheckof(id)
      local expr_f = algconstructor(alge_ct, "ohs", mref..mdim, nil)
      
      self[ctnum] = expr_f
      return expr_f(ohs)
    end
  end })
  
  return function(ohs)
    return dispatch[tonumber(typeof(ohs))](ohs)
  end
end

__add = binop("+")
__sub = binop("-")
__mul = binop("*")
__div = binop("/")
__pow = binop("^")
__mod = binop("%")

__unm = preop("-")

M.toelwfunction = preop

return M