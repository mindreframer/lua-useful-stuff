require "leslie.settings"
require "leslie.class-leslie0"
require "leslie.utils"

module("leslie.filters", package.seeall)

---
function add(var, arg)
  return tonumber(var) + tonumber(arg)
end

---
function addslashes(var)
  return var:gsub("\"", "\\\"")
end

---
function capfirst(var)
  return var:sub(1, 1):upper() .. var:sub(2)
end

---
function date(var, arg)
  arg = arg or leslie.settings.DATE_FORMAT

  return os.date(leslie.utils.date_format_convert(arg), var)
end

---
function default(var, arg)
  if not var or var == "" or var == false or var == 0 then
    do return arg end
  end
  return var
end

---
function default_if_none(var, arg)
  if var == nil then
    do return arg end
  end
  return var
end

---
function divisibleby(var, arg)
  return tonumber(var) % tonumber(arg) == 0
end

---
function filesizeformat(var)
  local size
  local size_map = {"KB", "MB", "GB", "TB"}
  
  var = tonumber(var)
  
  for i=4, 1, -1 do
    size = 1024^i
    if var > size then
      if i > 1 then
        do return tostring(string.format("%.1f", var/ size)) .." ".. size_map[i] end
      else
        do return tostring(string.format("%.0f", var/ size)) .." ".. size_map[i] end
      end
    end
  end
  
  return tostring(var) .." bytes"
end

--
function first(var)
  return var[1]
end

---
function get_digit(var, arg)
  var = tostring(var)
  local pos = #var - tonumber(arg) + 1
  
  return var:sub(pos, pos)
end

---
function join(var, arg)
  return table.concat(var, args)
end

---
function last(var)
  return var[#var]
end

---
function length(var)
  if type(var) == "number" then
    var = tostring(var)
  end
  
  return #var
end

---
function length_is(var, arg)
  return length(var) == tonumber(arg)
end

---
function linebreaksbr(var)
  return var:gsub("\n", "<br />")
end

---
function lower(var)
  return var:lower()
end

---
function random(var)
  return var[math.random(1, #var)]
end

---
function slice(var, arg)
  local t = {}
  local s, e = unpack(leslie.utils.split(arg, ':'))
  s, e = tonumber(s), tonumber(e)
  
  if not s then
    s = 0
  end

  if not e then
    e = #var
  elseif e < 0 then
    e = #var + e
  end
  
  if s == 0 and e == #var then
    do return var end
  end

  for i=s+1, e do
    t[#t+1] = var[i]
  end
  
  return t
end

---
function slugify(var, arg)
  return var:lower():gsub(" ", "-")
end

---
function time(var, arg)
  arg = arg or leslie.settings.TIME_FORMAT

  return os.date(leslie.utils.time_format_convert(arg), var)
end

---
function upper(var)
  return var:upper()
end

local register_filter = leslie.parser.register_filter

-- register builtin filters
register_filter("add")
register_filter("addslashes")
register_filter("capfirst")
register_filter("date")
register_filter("default")
register_filter("default_if_none")
register_filter("divisibleby")
register_filter("filesizeformat")
register_filter("first")
register_filter("get_digit")
register_filter("last")
register_filter("length")
register_filter("length_is")
register_filter("linebreaksbr")
register_filter("lower")
register_filter("random")
register_filter("slice")
register_filter("slugify")
register_filter("time")
register_filter("upper")