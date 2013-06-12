require"lpeg"
require"luma"
require"leg.parser"
require"leg.scanner"

local chunk = lpeg.P(leg.parser.apply(lpeg.V"Chunk"))

local syntax = [[
  defs <- _ definition* -> build_app _
  method <- 'method' _ ({name} _ funcbody _) -> build_method
  model <- 'model' _ ({name} _ methods 'end' _) -> build_model
  action <- 'action' _ ({name} _ '<-' _ pattern methods 'end' _) -> build_action
  view <- 'view' _ ({name} _ funcbody _) -> build_view
  methods <- method* -> {}
  pattern <- {string _ (',' _ string _)*}
  namelist <- ({name} _ (',' _ {name} _)*) -> {}
  params <- ('(' _ namelist _ ')') / ('(' {&.} _ ')') -> empty_nl
  funcbody <- ( params _ {chunk} _ 'end') -> build_funcbody
  definition <- (method / model / action / view)
]]

local defs = {
  empty_nl = function () return {} end,
  build_funcbody = function (params, body)
    return { params = params, body = body }
  end,
  build_method = function (name, body)
    return { type = "method", name = name, body = body }
  end,
  build_model = function (name, methods)
    for _, m in ipairs(methods) do
      table.insert(m.body.params, 1, "self")
      m.body = '(' .. table.concat(m.body.params,", ") .. ')' .. m.body.body .. " end"
     end
    return { type = "model", name = name, methods = methods }
  end,
  build_action = function (name, pattern, methods)
    for _, m in ipairs(methods) do
      table.insert(m.body.params, 1, "app")
      m.body = '(' .. table.concat(m.body.params,", ") .. ')' .. m.body.body .. " end"
    end
    return { type = "action", pattern = pattern, name = name,
      methods = methods }
  end,
  build_view = function (name, body)
    table.insert(body.params, 1, "app")
    body = '(' .. table.concat(body.params,", ") .. ')' .. body.body .. " end"
    return { type = "view", name = name, body = body }
  end,
  build_app = function (...)
    local defs = { ... }
    local app = { methods = {}, models = {}, actions = {}, views = {} }
    for i, v in ipairs(defs) do
      if v.type == "method" then
        v.body = '(' .. table.concat(v.body.params, ", ") .. ')' .. v.body.body .. ' end'
      end
      table.insert(app[v.type .. "s"], v)
    end
    return app
  end,
  chunk = chunk
}

local code = [[

  $methods[=[
    function _M.methods:$name$body
  ]=]

  _M:add_models{
  $models[=[
    $name = {
    $methods[==[
      $name = function $body,
    ]==]
    }
  ]=]
  }

  _M:add_controllers{
  $actions[=[
    $name = { $pattern,
    $methods[==[
      $name = function $body,
    ]==]
    }
  ]=]
  }

  _M:add_views{
  $views[=[
    $name = function $body,
  ]=]
  }

]]

luma.define("orbit_application", syntax, code, defs)
