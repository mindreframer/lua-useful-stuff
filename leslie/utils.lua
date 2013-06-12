require "lpeg"

module("leslie.utils", package.seeall)

local date_format_map = {
  ["%"] = "",
  ["N"] = "%b",
  ["j"]= "%d",
  ["Y"] = "%Y"
}

local time_format_map = {
  ["P"] = "%I %p"
}

local smart_split_re

do
  local quot, space = lpeg.S("\""), lpeg.S(" ")
  local tag = (1 - space) - quot
  local str = quot * (tag * (space * tag)^0)^0 * quot

  local elem = lpeg.C((tag + str)^1)
  smart_split_re = lpeg.Ct((elem * (space * elem)^0)^1)
end

---
function split(str, sep, trim)
  str = str .. sep
  local bits = {str:match((str:gsub("[^"..sep.."]*"..sep, "([^"..sep.."]*)"..sep)))}
  
  if trim then
    for i=1, #bits do
      bits[i] = strip(bits[i])
    end
  end
  
  for i=1, #bits do
    if bits[i]:sub(1, 1) == "\"" then
      bits[i] = bits[i]:sub(2, -2)
    end
  end
  
  return bits
end

---
function strip(s)
  return string.gsub(s, "^%s*(.-)%s*$", "%1")
end

---
function smart_split(s)

  if s == "" or s == nil then
    do return {} end
  end

  return lpeg.match(smart_split_re, s)
end

---
function format_convert(format, map)
  local str = {}
  
  for c in format:gmatch(".") do
    str[#str+1] = map[c] or c
  end
  
  return table.concat(str)
end

---
function date_format_convert(format)
  return format_convert(format, date_format_map)
end

---
function time_format_convert(format)
  return format_convert(format, time_format_map)
end