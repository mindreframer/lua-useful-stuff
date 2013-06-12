require"lpeg"
require"luma"
require"leg.parser"

local funcbody = lpeg.P(leg.parser.apply(lpeg.V"FuncBody"))
local stat = lpeg.P(leg.parser.apply(lpeg.V"Stat"))

local syntax = [[
  defs <- _ definition* -> build_class
  extends <- ('extends' _ {name} _) -> build_extends
  mixin <- ('include' _ {name} _) -> build_mixin
  classmethod <- 'class' _ 'method' _ ({name} _ {funcbody}) -> build_classmethod _
  instancemethod <- ('instance' _)? 'method' _ ({name} _ {funcbody}) -> build_instancemethod _
  definition <- extends / mixin / classmethod / instancemethod / ({stat} _)
]]

local defs = {
  build_classmethod = function (name, body)
    return { type = "method", name = "function _M." .. name, body = body }
  end,
  build_instancemethod = function (name, body)
    return { type = "method", name = "function _M.instance_methods:" .. name, body = body }
  end,
  build_extends = function (class)
    return { type = "extends", class = class }
  end,
  build_mixin = function (class)
    return { type = "mixin", class = class }
  end,
  build_class = function (...)
    local defs = { ... }
    local class = { parent = "", mixins = {}, methods = {} }
    for i, v in ipairs(defs) do
      if type(v) == "string" then
        table.insert(class.methods, { type = "stat", name = v, body = "" })
      elseif v.type == "extends" then
        class.parent = v.class
      elseif v.type == "mixin" then
        table.insert(class.mixins, { class = v.class })
      else
        table.insert(class.methods, v)
      end
    end
    return class
  end,
  funcbody = funcbody,
  stat = stat
}

local code = [[
  _M.instance_methods = _M.instance_methods or _M.methods or {}

  $mixins[=[
  do
    local mixin = require"$class"
    for k, v in pairs(mixin.instance_methods) do
      _M.instance_methods[k] = v
    end
  end
  ]=]

  if "$parent" ~= "" then
    local parent = require"$parent"
    setmetatable(instance_methods, { __index = parent.instance_methods })
    _M.super = parent.instance_methods
  end

  if not _M.new then
    function _M.new(...)
      local obj = {}
      setmetatable(obj, { __index = instance_methods })
      if obj.initialize then obj:initialize(...) end
      return obj
    end
  end

  $methods[=[
  $name $body
  ]=]
]]

luma.define("class_description", syntax, code, defs)
