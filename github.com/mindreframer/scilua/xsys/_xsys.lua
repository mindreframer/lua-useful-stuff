--------------------------------------------------------------------------------
-- A library for general purpose algorithms.
--
-- Copyright (C) 2011-2012 Stefano Peluchetti. All rights reserved.
--
-- Features, documention and more: http://www.scilua.org .
-- 
-- License: MIT (http://www.opensource.org/licenses/mit-license.php), full text
-- follows:
--------------------------------------------------------------------------------
-- Permission is hereby granted, free of charge, to any person obtaining a copy 
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights 
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell 
-- copies of the Software, and to permit persons to whom the Software is 
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in 
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE 
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER 
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.
--------------------------------------------------------------------------------

local cfg = require "xsys.config"

local M = {}

local logcompile = cfg.logcompile
local chk, err, split, trim, writeall, preprocess

-- Core: compile ---------------------------------------------------------------

local lognum = setmetatable({}, { __index = function(self, k)
  self[k] = 0
  return self[k]
end })

local function compile(code, name, env, prep, ...)
  if logcompile then
    local n = lognum[name]
    lognum[name] = lognum[name] + 1
    name = n == 0 and name or name..tostring(n)   
  end
  if prep then 
    code = preprocess(code, type(prep) == "table" and prep or {}, ...)
  end
  local f, e = loadstring(code, name)
  if not f then
    err("parse", "syntax error in chunk: "..e.."\n"..code)
  end
  if env then 
    setfenv(f, env)
  end
  local ok, fe = pcall(f)
  if not ok then
    err("parse", "error executing chunk: "..fe.."\n"..code)
  end
  if logcompile then
    writeall(logcompile.."/"..name..".lua", code)
  end
  return fe
end
M.compile = compile

-- Core: preprocess ------------------------------------------------------------

-- Based on Steve Dovan preprocessor:
-- https://github.com/stevedonovan/Penlight/blob/master/lua/pl/template.lua .

do

local insert, format = table.insert, string.format

local function parseDollarParen(exec_pat, pieces, chunk, s, e)
  local s = 1
  for term, executed, e in chunk:gmatch(exec_pat) do
    executed = '('..executed:sub(2, -2)..')'
    insert(pieces, format("%q..(%s or '')..",chunk:sub(s, term - 1), 
                          executed))
    s = e
  end
  insert(pieces, format("%q", chunk:sub(s)))
end

local function parseHashLines(chunk, brackets, esc)
  local exec_pat = "()$(%b"..brackets..")()"
  local esc_pat = esc.."+([^\n]*\n?)"
  local esc_pat1, esc_pat2 = "^"..esc_pat, "\n"..esc_pat
  local  pieces, s = { "return function(_put) ", n = 1 }, 1
  while true do
    local ss, e, lua = chunk:find(esc_pat1, s)
    if not e then
      ss, e, lua = chunk:find(esc_pat2, s)
      insert(pieces, "_put(")
      parseDollarParen(exec_pat, pieces, chunk:sub(s, ss))
      insert(pieces, ")")
      if not e then break end
    end
    insert(pieces, lua)
    s = e + 1
  end
  insert(pieces, " end")
  return table.concat(pieces)
end

preprocess = function(str, env, brackets, escape)
  env      = env      or {}
  brackets = brackets or "()"
  escape   = escape   or "#"
  local code = parseHashLines(str, brackets, escape)
  local dumper = compile(code, "preprocessor", env)
  local o = {}
  dumper(function(s) insert(o, s) end)
  return table.concat(o)
end
M.preprocess = preprocess

end

-- Core: cache -----------------------------------------------------------------

local function check1(...)
  if not (select("#", ...) == 1) then
    err("misuse", "require 1 return value and 1 hash key: "..select("#", ...))
  end
  return ...
end

local cachewk = { __mode = "k" }

local function cache(f, persist, hash)
  chk(persist == "strong" or persist == "weak", "constraint",
      "argument #2 must be 'strong' or 'weak'")
  local localcache = setmetatable({}, persist == "weak" and cachewk or nil)
  return function(...)
    local hashk = hash and check1(hash(...)) or check1(...)
    localcache[hashk] = localcache[hashk] or check1(f(...))
    return localcache[hashk]
  end
end
M.cache = cache

-- Core: error handling --------------------------------------------------------

-- TODO: special nomem handling?
local error_mt = { __tostring = function(self)
  local module  = self.module
  local code    = "["..self.code.."]"
  local message = ": "..self.message
  return module..code..message
end }

M.handlers = function(module)
  local function err(code, message)
    local o = { module = module, code = code, message = message }
    -- TODO: Enable table error in next release.
    error(tostring(setmetatable(o, error_mt)))
  end
  local function chk(condition, code, ...)
    if not condition then
      local arg, n = { ... }, select("#", ...)
      for i=1,n do
  arg[i] = tostring(arg[i])
      end
      err(code, table.concat(arg, ""))
    end
  end
  return err, chk
end

err, chk = M.handlers("xsys")

-- Core: copy ------------------------------------------------------------------

local copy_disp = {} -- Dispatch table for copying single object.

local function copy_single(x)
	return copy_disp[type(x)](x)
end

-- TODO: "default copy operation" on table dangerous?
-- Table objects with optional copy member function.
copy_disp.table = function(x)
  if x.copy then 
    return x:copy()
  else
    local o = {}
    for k, v in pairs(x) do
      o[k] = copy_single(v)
    end
    -- Metatables are always shared.
    return setmetatable(o, getmetatable(x))
  end
end

-- Cdata objects requires copy member function.
copy_disp.cdata = function(x)	return x:copy() end

-- Closures are shared.
copy_disp["function"] = function(x) return x end

-- These have value semantics no copy required.
copy_disp.string  = function(x) return x end
copy_disp.number  = function(x) return x end
copy_disp.boolean = function(x) return x end
copy_disp["nil"]	= function(x) return x end

-- Perform a "by-value" copy of multiple tables or cdata objects.
function M.copy(...)
	local o = {}
	for i=1,select("#",...) do
		o[i] = copy_single(select(i, ...))
	end
	return unpack(o)
end

-- Core: dry features ----------------------------------------------------------

local getter = cache(function(keystr)
  local keys = split(keystr, ",")
  local o = {}
  for i=1,#keys do
    o[i] = "x."..trim(keys[i])
  end
  o = table.concat(o, ",")
  local s = "return function(x) return "..o.." end"
  local f = compile(s, "getter")
  return f
end, "strong")

local function from(what, keystr)
  return getter(keystr)(what)
end
M.from = from

local function import(to, from)
  for k,v in pairs(from) do
    if to[k] then -- Avoid overwriting.
      err("error", "key "..k.." already present in "..tostring(to))
    end
    to[k] = v
  end
end
M.import = import



-- Core: serialization ---------------------------------------------------------

function M.archive(obj)
  return tostring(obj)
end

local global = {} -- To avoid strict module effect.
M.import(global, _G)

local load_mt
load_mt = { 
  __index = function(self, k)
    local news = self._s..k
    if global[news] then return global[news] end
    local ok, loaded = pcall(require, news)
    if not ok then
      return setmetatable({ _s = news.."." }, load_mt)
    else
      self[news] = loaded
      return loaded
    end
  end 
}

-- TODO: Change to first try the most specialized, ex (sci.alg.vec.one):
-- TODO: "sci.alg.vec".one -> "sci.alg".vec.one -> "sci".alg.vec.one
-- TODO: -> sci.alg.vec.one.
function M.restore(str)
  local env = setmetatable({ _s = "" }, load_mt)
  return M.compile("return "..str, "restore", env)
end

-- Io --------------------------------------------------------------------------

-- TODO: introduce new other error codes for io operations?
M.io = {}
M.import(M.io, io)

function M.io.readall(filestr)
  local f, e = io.open(filestr)
  if not f then
    err("error", "failed to open "..filestr.." in read mode: "..e)
  end
  local s = f:read("*a")
  if not f:close() then
    err("error", "failed to read from "..filestr)
  end
  return s
end

writeall = function(filestr, str)
  local f, e = io.open(filestr, "w")
  if not f then
    err("error", "failed to open "..filestr.." in write mode: "..e)
  end
  f:write(str)
  if not f:close() then
    err("error", "failed to write on "..filestr)
  end
end
M.io.writeall = writeall

-- String ----------------------------------------------------------------------

M.string = {}
M.import(M.string, string)

-- Credit: Steve Dovan.
split = function(s, re)
  local i1, ls = 1, {}
  local insert = table.insert
  if not re then re = '%s+' end
  if re == '' then return { s } end
  while true do
    local i2, i3 = s:find(re, i1)
    if not i2 then
      local last = s:sub(i1)
      if last ~= '' then insert(ls, last) end
      if #ls == 1 and ls[1] == '' then
        return  {}
      else
        return ls
      end
    end
    insert(ls, s:sub(i1, i2 - 1))
    i1 = i3 + 1
  end
end
M.string.split = split

-- TODO: what = "lr"
trim = function(s)
  return (s:gsub("^%s*(.-)%s*$", "%1"))
end
M.string.trim = trim

-- TODO: finish implementation, more robust.
local function ident(s, n)
  if n == 0 then
    return s
  elseif n < 0 then
    local sp = split(s, "[\n\r]")
    for i=1,#sp do
      sp[i] = sp[i]:sub(-n + 1)
    end
    return table.concat(sp, "\n")
  else
    error("NYI")
  end
end

-- Table -----------------------------------------------------------------------

M.table = {}
M.import(M.table, table)

function M.table.apply(t, f, ...) -- Inplace.
  for i=1,#t do
    t[i] = f(t[i], ...)
  end
end

function M.table.eval(t, f, ...) -- Inplace.
  for i=1,#t do
    f(t[i], ...)
  end
end

function M.table.join(...)
  local o = {}
  local nt = select("#", ...)
  for e=1,nt do
    local t = select(e, ...)
    for i=1,#t do
      table.insert(o, t[i])
    end
  end
  return o
end

function M.table.transpose(t, tncol)
  tncol = tncol or #t[1]
  local tnrow = #t
  local o = {}
  for i=1,tncol do
    o[i] = {}
    for j=1,tnrow do
      o[i][j] = t[j][i]
    end
  end
  return o
end

-- Bit -------------------------------------------------------------------------

local bit = require "bit"
local ffi = require "ffi"
local tobit, lshift, rshift = bit.tobit, bit.lshift, bit.rshift
local band, bor, bxor =  bit.band, bit.bor, bit.bxor

M.bit = {}
M.import(M.bit, bit)

-- 99 == not used.
local lsb_array = ffi.new("const int32_t[64]", {32, 0, 1, 12, 2, 6, 99, 13,
  3, 99, 7, 99, 99, 99, 99, 14, 10, 4, 99, 99, 8, 99, 99, 25, 99, 99, 99, 99,  
  99, 21, 27, 15, 31, 11, 5, 99, 99, 99, 99, 99, 9, 99, 99, 24, 99, 99, 20, 26, 
  30, 99, 99, 99, 99, 23, 99, 19, 29, 99, 22, 18, 28, 17, 16, 99})

-- Compute position of least significant bit, starting with 0 for the tail of
-- the bit representation and ending with 31 for the head of the bit
-- representation (right to left). If all bits are 0 then 32 is returned.
-- This corresponds to finding the i in 2^i if the 4-byte value is set to 2^i.
-- Branch free version.
function M.bit.lsb(x)
  x = band(x, -x)
  x = tobit(lshift(x, 4) + x)
  x = tobit(lshift(x, 6) + x)
  x = tobit(lshift(x, 16) - x)
  return lsb_array[rshift(x, 26)]
end

return M