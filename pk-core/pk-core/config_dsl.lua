--------------------------------------------------------------------------------
-- config_dsl.lua
-- This file is a part of pk-core library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------

local lfs = require 'lfs'

--------------------------------------------------------------------------------

local tostring, type, assert, select, loadfile, error, pcall, import
    = tostring, type, assert, select, loadfile, error, pcall, import

local os = os
local io = io
local table = table

--------------------------------------------------------------------------------

local arguments,
      optional_arguments,
      method_arguments
      = import 'lua-nucleo/args.lua'
      {
        'arguments',
        'optional_arguments',
        'method_arguments'
      }

local is_function
      = import 'lua-nucleo/type.lua'
      {
        'is_function'
      }

local empty_table,
      tkeys,
      tclone,
      twithdefaults,
      treadonly,
      tidentityset
      = import 'lua-nucleo/table-utils.lua'
      {
        'empty_table',
        'tkeys',
        'tclone',
        'twithdefaults',
        'treadonly',
        'tidentityset'
      }

local tpretty
      = import 'lua-nucleo/tpretty.lua'
      {
        'tpretty'
      }

local tstr
      = import 'lua-nucleo/tstr.lua'
      {
        'tstr'
      }

local invariant
      = import 'lua-nucleo/functional.lua'
      {
        'invariant'
      }

local unique_object
      = import 'lua-nucleo/misc.lua'
      {
        'unique_object'
      }

local do_in_environment,
      dostring_in_environment,
      make_config_environment
      = import 'lua-nucleo/sandbox.lua'
      {
        'do_in_environment',
        'dostring_in_environment',
        'make_config_environment'
      }

local load_all_files,
      find_all_files
      = import 'lua-aplicado/filesystem.lua'
      {
        'load_all_files',
        'find_all_files'
      }

local make_loggers
      = import 'pk-core/log.lua'
      {
        'make_loggers'
      }

local load_data_walkers,
      load_data_schema
      = import 'pk-core/walk_data_with_schema.lua'
      {
        'load_data_walkers',
        'load_data_schema'
      }

--------------------------------------------------------------------------------

local log, dbg, spam, log_error = make_loggers("pk-core/config_dsl", "CDL")

--------------------------------------------------------------------------------

-- Generalized initializing function for data_walkers
local build_config_dsl = function()
  -- Private method
  local string_to_node = function(self, node)
    method_arguments(
        self,
        "string", node
      )

    if not node:find("^return%s") then
      node = "return " .. node
    end

    local ok, result = dostring_in_environment(
        node,
        self.env_,
        "@" .. (table.concat(self:get_current_path(), "."))
      )
    if not ok then
      -- Caller should call self:fail on failure
      -- (or wrap call in self:ensure).
      local err = result
      return nil, err
    end

    return result
  end

  --
  -- Use these types to define your config file schema.
  --

  types:up "cfg:boolean" (function(self, info, value)
    self:ensure_equals("unexpected type", type(value), "boolean")
  end)

  types:up "cfg:number" (function(self, info, value)
    self:ensure_equals("unexpected type", type(value), "number")
  end)

  types:up "cfg:integer" (function(self, info, value)
    local _ =
      self:ensure_equals("unexpected type", type(value), "number"):good()
      and self:ensure("must be integer", value % 1 == 0, value)
  end)

  types:up "cfg:positive_integer" (function(self, info, value)
    local _ =
      self:ensure_equals("unexpected type", type(value), "number"):good()
      and self:ensure("must be integer", value % 1 == 0, value):good()
      and self:ensure("must be > 0", value > 0, value)
  end)

  types:up "cfg:port" (function(self, info, value)
    local _ =
      self:ensure_equals("unexpected type", type(value), "number"):good()
      and self:ensure(
          "port value must be integer", value % 1 == 0, value
        ):good()
      and self:ensure("port value too small", value >= 1, value):good()
      and self:ensure("port value too large", value <= 65535, value)
  end)

  types:up "cfg:string" (function(self, info, value)
    self:ensure_equals("unexpected type", type(value), "string")
  end)

  types:up "cfg:optional_string" (function(self, info, value)
    self:ensure(
        "unexpected type",
        value == nil or type(value) == "string",
        type(value)
      )
  end)

  types:up "cfg:non_empty_string" (function(self, info, value)
    local _ =
      self:ensure_equals("unexpected type", type(value), "string"):good()
      and self:ensure("string must not be empty", value ~= "")
  end)

  types:up "cfg:host" (function(self, info, value)
    local _ =
      self:ensure_equals("unexpected type", type(value), "string"):good()
      and self:ensure("host string must not be empty", value ~= "")
  end)

  types:up "cfg:optional_host" (function(self, info, value)
    local _ =
      self:ensure(
          "unexpected type",
          value == nil or type(value),
          "string"
        )
  end)

  types:up "cfg:path" (function(self, info, value)
    local _ =
      self:ensure_equals("unexpected type", type(value), "string"):good()
      and self:ensure("path string must not be empty", value ~= "")
  end)

  types:up "cfg:optional_path" (function(self, info, value)
    if value ~= nil then
      local _ =
        self:ensure_equals("unexpected type", type(value), "string"):good()
        and self:ensure("path string must not be empty", value ~= "")
    end
  end)

  types:up "cfg:url" (function(self, info, value)
    local _ =
      self:ensure_equals("unexpected type", type(value), "string"):good()
      and self:ensure("url string must not be empty", value ~= "")
  end)

  types:up "cfg:existing_path" (function(self, info, value)
    local _ =
      self:ensure_equals("unexpected type", type(value), "string"):good()
      and self:ensure("path string must not be empty", value ~= ""):good()
      and self:ensure("path must exist", lfs.attributes(value))
  end)

  --path to source file, suitable for "require" or "import"

  types:up "cfg:importable_path" (function(self, info, value)
    local _ =
      self:ensure_equals("unexpected type", type(value), "string"):good()
      and self:ensure("path string must not be empty", value ~= ""):good()
      and self:ensure("path must be importable", pcall(import, value)):good()
  end)

  types:up "cfg:enum_value" (function(self, info, value)
    if not info.values_set then
      info.values_set = tidentityset(
          assert(info.values, "bad schema: missing enum values")
        )
    end
    if info.values_set[value] == nil then
      self:fail(
          "unexpected value `" .. tostring(value) .. "',"
       .. " expected one of { "
       .. table.concat(tkeys(info.values_set), " | ")
       .. " }"
        )
    end
  end)

  types:up "cfg:optional_freeform_table" (function(self, info, value)
    self:ensure(
        "unexpected type",
        value == nil or type(value) == "table",
        type(value)
      )
  end)

  types:up "cfg:freeform_table" (function(self, info, value)
    self:ensure_equals("unexpected type", type(value), "table")
  end)

  types:variant "cfg:variant"

  types:ilist "cfg:ilist"

  types:ilist "cfg:non_empty_ilist" (function(self, info, value)
    self:ensure("ilist must not be empty", #value > 0)
  end)

  types:node "cfg:table" (function(self, info, value)
    self:ensure_equals("unexpected type", type(value), "table")
  end)

  types:node "cfg:node"
  {
    loadhook = string_to_node;
  }

  types:node "cfg:optional_node"
  {
    optional = true;
    loadhook = string_to_node;
  }

  types:root "cfg:root"

  --
  -- Technical details below
  --

  local ensure_equals = function(self, msg, actual, expected)
    if actual ~= expected then
      self.checker_:fail(
          msg .. ":"
       .. " actual: " .. tostring(actual)
       .. ", expected: " .. tostring(expected)
        )
    end
    return self
  end

  local ensure = function(self, ...)
    self.checker_:ensure(...)
    return self
  end

  local fail = function(self, msg)
    self.checker_:fail(msg)
    return self
  end

  local good = function(self)
    return self.checker_:good()
  end

  types:factory (function(checker, get_current_path_closure, env)
    env = env or empty_table

    return
    {
      ensure_equals = ensure_equals;
      ensure = ensure;
      fail = fail;
      good = good;
      --
      get_current_path = get_current_path_closure;
      --
      checker_ = checker;
      env_ = env;
    }
  end)

end

--------------------------------------------------------------------------------

local get_data_walkers
do
  -- TODO: Heavy. Initialize on-demand?
  local walkers = load_data_walkers(build_config_dsl)

  -- TODO: Need write-protection.
  get_data_walkers = invariant(walkers)
end

return
{
  build_config_dsl = build_config_dsl;
  get_data_walkers = get_data_walkers;
}
