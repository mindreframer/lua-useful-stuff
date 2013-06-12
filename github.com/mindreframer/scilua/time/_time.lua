--------------------------------------------------------------------------------
-- A library for the manipulation of dates and periods according to the
-- Gregorian calendar, requires LuaJIT 2.0.
--
-- Copyright (C) 2011-2012 Stefano Peluchetti. All rights reserved.
--
-- Features, documention and more: http://www.scilua.org .
-- 
-- Credit: the Gregorian calendar routines contained in this library are 
-- ported from Claus Tøndering calendar algorithms:
-- http://www.tondering.dk/main/index.php/calendar-information .
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

local M = {}

local ffi  = require "ffi"
local bit  = require "bit"
local xsys = require "xsys"

local err, chk = xsys.handlers("time")
local abs, floor = math.abs, math.floor

-- Checks ----------------------------------------------------------------------

local int64_ct = ffi.typeof("int64_t")

local checks = {
  int   = function(x) return type(x) == "number" and x == math.floor(x) end;
  int64 = function(x) return ffi.istype(int64_ct, x) end;
  str   = function(x) return type(x) == "string" end;
}

-- TODO: improve error reporting with function name and passed arguments.
--
-- Return a test function based on an arbitrary number of tests (functions 
-- taking 1 argument and returning bool) identified by the keys of table checks. 
-- If none of the tests returns true an error is thrown.
local function new_check(...)
  local args = { ... }
  local exprs, env = {}, { err = err, tos = tostring, type = type }
  for i=1,#args do
    exprs[i] = "expr"..i
    env[exprs[i]] = assert(checks[args[i]])
  end
  local s = "return function(x) if not("..table.concat(exprs, "(x) or ").."(x))"
  s = s.." then err('constraint', "
  s = s.."tos(x)..' ('..type(x)..') does not satisfy any of: "
  s = s..table.concat(args, ", ").."') end end"
  local f = assert(loadstring(s))
  setfenv(f, env)
  return f()
end

local T_int       = new_check("int")
local T_int64     = new_check("int64")
local T_int64_str = new_check("int64", "str")
local T_str       = new_check("str")

-- Period ----------------------------------------------------------------------
-- Metatable, low-level constructor.
local p_mt, p_ct = {}
p_mt.__index = p_mt

checks.period = function(x) return ffi.istype(p_ct, x) end

local T_period     = new_check("period")
local T_int_period = new_check("int", "period")

-- Expose int64.
function p_mt:ticks() return self._ticks end

function p_mt:microseconds()
  return tonumber(self._ticks % 1e6)
end
function p_mt:seconds()
  return tonumber((self._ticks/1e6) % 60)
end
function p_mt:minutes()
  return tonumber((self._ticks/(1e6*60)) % 60)
end
function p_mt:hours()
  return tonumber(self._ticks/(1e6*60*60))
end
function p_mt:parts()
  return self:hours(), self:minutes(), self:seconds(), self:microseconds()
end

function p_mt:copy() return p_ct(self._ticks) end

-- Return string representation for a positive period.
local function posptostr(h, m, s, ms)
  return string.format("%02i:%02i:%02i.%06i", h, m, s, ms)
end

function p_mt:__tostring()
  local h, m, s, ms = self:parts()
  if self._ticks >= 0 then
    return posptostr(h, m, s, ms)
  else
    return "-"..posptostr(-h, -m, -s, -ms)
  end
end

function p_mt:__eq(rhs) T_period(rhs)
  return self._ticks == rhs._ticks
end
function p_mt:__lt(rhs) T_period(rhs)
  return self._ticks < rhs._ticks
end
-- TODO: remove when LuaJIT support fallback to lt.
function p_mt:__le(rhs) T_period(rhs)
  return self._ticks <= rhs._ticks
end

function p_mt:__add(rhs) T_int_period(rhs)
  return p_ct(self._ticks + rhs._ticks) -- Commutative by design.
end
function p_mt:__sub(rhs) T_period(rhs)
  return p_ct(self._ticks - rhs._ticks)
end
function p_mt:__unm()
  return p_ct(-self._ticks)
end
function p_mt:__mul(rhs) T_int_period(rhs) -- Commutative.
  if ffi.istype(p_ct, rhs) then return p_mt.__mul(rhs, self) end
  return p_ct(self._ticks*rhs)
end
-- Approximate ratio, non-reversible in both cases.
function p_mt:__div(rhs) T_int_period(rhs)
  if ffi.istype(p_ct, rhs) then
    return tonumber(self._ticks)/tonumber(rhs._ticks)
  end
  return p_ct(self._ticks/rhs) -- Arg is int.
end

p_ct = ffi.metatype("struct { int64_t _ticks; }", p_mt)
M.period_ct = p_ct

-- Constructor (all checks).
local function period(h, m, s, ms)
  h = h or 0; m = m or 0; s = s or 0; ms = ms or 0;
  T_int(h); T_int(m); T_int(s); T_int(ms);
  return p_ct(h*(1e6*60*60LL)+m*(1e6*60LL)+s*(1e6*1LL)+ms)
end
M.period = period

function M.weeks(x)        T_int(x) return p_ct(x*(1e6*60*60*24*7LL)) end
function M.days(x)         T_int(x) return p_ct(x*(1e6*60*60*24LL)) end
function M.hours(x)        T_int(x) return p_ct(x*(1e6*60*60LL)) end
function M.minutes(x)      T_int(x) return p_ct(x*(1e6*60LL)) end
function M.seconds(x)      T_int(x) return p_ct(x*(1e6*1LL)) end
function M.milliseconds(x) T_int(x) return p_ct(x*(1e3*1LL)) end
function M.microseconds(x) T_int(x) return p_ct(x) end

local function toperiod(x) T_int64_str(x)
  if type(x) == "string" then
    local f1, l1, h, m, s, ms = x:find("(%d+):(%d+):(%d+).(%d+)")
    if (h == nil) or (ms == nil) then
      err("parse", x.." is not a string representation of a period")
    end
    if l1 ~= #x then
      err("parse", x.." contains additional data after period")
    end
    local ton = tonumber
    return period(ton(h), ton(m), ton(s), ton(ms))
  end
  return p_ct(x) -- Arg is int64.
end
M.toperiod = toperiod

-- Months ----------------------------------------------------------------------
local months_mt = {}
months_mt.__index = months_mt -- Tag only.

local months_ct = ffi.metatype("struct { int32_t _count; }", months_mt)
M.months_ct = months_ct

function M.months(x) T_int(x)
  return months_ct(x)
end

function checks.months(x) return ffi.istype(months_ct, x) end

-- Years -----------------------------------------------------------------------
local years_mt = {}
years_mt.__index = years_mt

local years_ct = ffi.metatype("struct { int32_t _count; }", years_mt)
M.years_ct = years_ct

function M.years(x) T_int(x)
  return years_ct(x)
end

function checks.years(x) return ffi.istype(years_ct, x) end

-- Date ------------------------------------------------------------------------
-- Metatable, low-level constructor, lower and upper bounds, 
-- low-level constructor which checks for range, constructor (all checks).
local d_mt, d_ct, d_min, d_max, d_ctrange, date = {}
d_mt.__index = d_mt

function checks.date(x) return ffi.istype(d_ct, x) end

function checks.daterange(x) return
  ffi.istype(int64_ct, x) and d_min <= x and x <= d_max
end

function checks.year(x) -- 1582 adoption, 9999 to keep 4 chars for years part.
  return type(x) == "number" and x == math.floor(x) and 1582 <= x and x <= 9999
end

function checks.month(x)
  return type(x) == "number" and x == math.floor(x) and 1 <= x and x <= 12
end

local T_date                     = new_check("date")
local T_daterange                = new_check("daterange")
local T_year                     = new_check("year")
local T_month                    = new_check("month")
local T_period_months_years      = new_check("period","months","years")
local T_period_months_years_date = new_check("period","months","years","date")

local function isleapyear(x)
  return (x % 4 == 0) and ((x % 100 ~= 0) or (x % 400 == 0))
end
function M.isleapyear(x) T_year(x)
  return isleapyear(x) 
end
function d_mt:isleapyear()
  return isleapyear(self:year())
end

local eom = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }

local function endofmonth(year, month)
  return (month == 2 and isleapyear(year)) and 29 or eom[month]
end
function M.endofmonth(x, month) T_year(x) T_month(month)
  return endofmonth(x, month)
end
function d_mt:endofmonth()
  return endofmonth(self:ymd())
end

local function weekday(year, month, day)
  local a = floor((14 - month)/12)
  local y = year - a
  local m = month + 12*a - 2
  local d = (day + y + floor(y/4) - floor(y/100) + floor(y/400) +
    floor((31*m)/12)) % 7
  return d == 0 and 7 or d -- Days of week from 1 = Monday to 7 = Sunday.
end
function M.weekday(x, month, day) T_year(x) T_month(month) T_int(day)
  if not (1 <= day and day <= endofmonth(x, month)) then
    err("constraint", "invalid day in ymd: "..x..","..month..","..day)
  end
  return weekday(x, month, day)
end
function d_mt:weekday()
  return weekday(self:ymd())
end

local function ymd_to_julian(year, month, day)
  -- Range of Lua number suffices for this function.
  local a = floor((14 - month)/12)
  local y = year + 4800 - a
  local m = month + 12*a - 3
  return day + floor((153*m + 2)/5) + 365*y + floor(y/4) - floor(y/100) +
    floor(y/400) - 32045
end

local function julian_to_ymd(julian)
  -- Range of Lua number suffices for this function.
  local a = julian + 32044
  local b = floor((4*a + 3)/146097)
  local c = a - floor((146097*b)/4)
  local d = floor((4*c + 3)/1461)
  local e = c - floor((1461*d)/4)
  local m = floor((5*e + 2)/153)
  local day = e - floor((153*m + 2)/5) + 1
  local month = m + 3 - 12*floor(m/10)
  local year = 100*b + d - 4800 + floor(m/10)
  return year, month, day
end

function d_mt:__eq(rhs) T_date(rhs)
  return self._ticks == rhs._ticks
end
function d_mt:__lt(rhs) T_date(rhs)
  return self._ticks < rhs._ticks
end
-- TODO: remove when LuaJIT support fallback to lt.
function d_mt:__le(rhs) T_date(rhs)
  return self._ticks <= rhs._ticks
end

-- Assumes only violation of valid date may be in day outside of end of month
-- due to months and years shifts. Cap the day and returns a valid date.
local function valid_date(year, month, day)
  day = math.min(day, endofmonth(year, month))
  -- Date constructor performs extra useless (here) checks, use below:
  local julian = ymd_to_julian(year, month, day)
  return d_ctrange(julian*(86400LL*1e6)) -- Need to test for range.
end

local function shift_months(y, m, dm)
  local newm = (m - 1 + dm) % 12 + 1
  local newy = y + floor((m - 1 + dm)/12)
  return newy, newm
end

function d_mt:__add(rhs) -- Commutative.
  if ffi.istype(d_ct, rhs) then return d_mt.__add(rhs, self) end
  T_period_months_years(rhs)
  if ffi.istype(p_ct, rhs) then return d_ctrange(self._ticks + rhs._ticks) end
  if ffi.istype(months_ct, rhs) then
    local y, m, d = self:ymd()
    y, m = shift_months(y, m, rhs._count)
    return valid_date(y, m, d) + self:period()
  end
  local y, m, d = self:ymd()
  return valid_date(y + rhs._count, m, d) + self:period() -- Arg is years.
end

function d_mt:__sub(rhs) T_period_months_years_date(rhs)
  if ffi.istype(p_ct, rhs) then return d_ctrange(self._ticks - rhs._ticks) end
  if ffi.istype(months_ct, rhs) then
    local y, m, d = self:ymd()
    y, m = shift_months(y, m, -rhs._count)
    return valid_date(y, m, d) + self:period()
  end
  if ffi.istype(years_ct, rhs) then
    local y, m, d = self:ymd()
    return valid_date(y - rhs._count, m, d) + self:period()
  end
  return p_ct(self._ticks - rhs._ticks) -- Arg is date.
end

function d_mt:copy() return d_ct(self._ticks) end

function d_mt:__tostring()
  local year, month, day = self:ymd()
  local h, m, s, ms = self:period():parts()
  return string.format("%i-%02i-%02iT", year, month, day)
       ..posptostr(h, m, s, ms)
end

function d_mt:ymd()
  local julian = tonumber(self._ticks/(86400LL*1e6))
  return julian_to_ymd(julian)
end

function d_mt:year()  local y, m, d = self:ymd(); return y end
function d_mt:month() local y, m, d = self:ymd(); return m end
function d_mt:day()   local y, m, d = self:ymd(); return d end

function d_mt:period()
  return p_ct(self._ticks % (86400LL*1e6))
end

-- Expose int64.
function d_mt:ticks() return self._ticks end

d_ct = ffi.metatype("struct { int64_t _ticks; }", d_mt)
M.date_ct = d_ct

d_ctrange = function(x) T_daterange(x)
  return d_ct(x)
end

date = function(year, month, day) T_year(year) T_month(month) T_int(day)
  if not (1 <= day and day <= endofmonth(year, month)) then
    err("constraint", "invalid day in ymd: "..year..","..month..","..day)
  end
  return d_ct(ymd_to_julian(year, month, day)*(86400LL*1e6))
end
M.date = date

d_min = 198622713600000000LL -- date(1582, 1, 1)
d_max = 464269103999999999LL -- date(9999,12,31) + period(23, 59, 59, 999999)

function M.todate(x) T_int64_str(x)
  if type(x) == "string" then
    local f1, l1, year, month, day, h, m, s, ms = 
      x:find("(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+).(%d+)")
    if (year == nil) or (ms == nil) then
      err("parse", x.." is not a string representation of a date")
    end
    if l1 ~= #x then
      err("parse", x.." contains additional data after date")
    end
    local ton = tonumber
    return date(ton(year), ton(month), ton(day)) + 
      period(ton(h), ton(m), ton(s), ton(ms))
  end
  return d_ctrange(x) -- Arg is int64.
end

--	UtcTime, LocalTime ---------------------------------------------------------
-- TODO: implement for other systems.
if jit.os == "Windows" then
  ffi.cdef[[
  typedef unsigned long DWORD;
  typedef unsigned short WORD;
  typedef unsigned long long ULONGLONG;
  
  typedef struct {
    DWORD dwLowDateTime;
    DWORD dwHighDateTime;
  } FILETIME, *PFILETIME;
  
  typedef struct {
    WORD wYear;
    WORD wMonth;
    WORD wDayOfWeek;
    WORD wDay;
    WORD wHour;
    WORD wMinute;
    WORD wSecond;
    WORD wMilliseconds;
  } SYSTEMTIME, *PSYSTEMTIME;
  
  typedef union _ULARGE_INTEGER {
    struct {
      DWORD LowPart;
      DWORD HighPart;
    };
    struct {
      DWORD LowPart;
      DWORD HighPart;
    } u;
    ULONGLONG QuadPart;
  } ULARGE_INTEGER, *PULARGE_INTEGER;
  
  void GetSystemTimeAsFileTime(PFILETIME lpSystemTimeAsFileTime);
  bool FileTimeToSystemTime(const FILETIME *lpFileTime,
    PSYSTEMTIME lpSystemTime);
  void GetLocalTime(PSYSTEMTIME lpSystemTime);
  ]]
  
  local ft_ct = ffi.typeof("FILETIME")
  local st_ct = ffi.typeof("SYSTEMTIME")
  local ul_ct = ffi.typeof("ULARGE_INTEGER")
  local C = ffi.C
  local ftoffset = 199222329599999000ULL
  
  local st = st_ct() -- Buffer.
  function M.nowlocal()
    C.GetLocalTime(st)
    return date(st.wYear, st.wMonth, st.wDay) + period(st.wHour, st.wMinute,
      st.wSecond, st.wMilliseconds*1000)
  end
  
  -- TODO: Can we just use an int64_t here?
  local ul = ul_ct() -- Buffer.
  local function ft_to_int64(x)
    ul.LowPart = x.dwLowDateTime
    ul.HighPart = x.dwHighDateTime
    return ul.QuadPart
  end
  
  local ft = ft_ct() -- Buffer.
   -- No daylight adjustment, potentially faster and more precise.
  function M.nowutc()
    C.GetSystemTimeAsFileTime(ft)
    return d_ct(ft_to_int64(ft)/10 + ftoffset)
  end
end -- Windows.

return M