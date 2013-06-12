--------------------------------------------------------------------------------
-- tree_walker_with_checker.lua: data walking with fancy checking facilities
-- This file is a part of pk-core library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------
-- Sandbox warning: alias all globals!
--------------------------------------------------------------------------------

local assert, error, tostring, rawget, getmetatable, setmetatable
    = assert, error, tostring, rawget, getmetatable, setmetatable

local table_insert, table_remove, table_concat
    = table.insert, table.remove, table.concat

--------------------------------------------------------------------------------

local log, dbg, spam, log_error
      = import 'pk-core/log.lua' { 'make_loggers' } (
          "pk-core/tree_walker_with_checker", "TWC"
        )

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

local is_string
      = import 'lua-nucleo/type.lua'
      {
        'is_string'
      }

local assert_is_function,
      assert_is_nil
      = import 'lua-nucleo/typeassert.lua'
      {
        'assert_is_function',
        'assert_is_nil'
      }

local timap
      = import 'lua-nucleo/table-utils.lua'
      {
        'timap'
      }

local do_nothing
      = import 'lua-nucleo/functional.lua'
      {
        'do_nothing'
      }

local make_checker
      = import 'lua-nucleo/checker.lua'
      {
        'make_checker'
      }

local unique_object
      = import 'lua-nucleo/misc.lua'
      {
        'unique_object'
      }

local common_load_schema
      = import 'pk-core/common_load_schema.lua'
      {
        'common_load_schema'
      }

local walk_tagged_tree
      = import 'pk-core/tagged-tree.lua'
      {
        'walk_tagged_tree'
      }

--------------------------------------------------------------------------------

local create_tree_walker_with_checker_factory
do
  local default_factory
  do
    local checker = function(self)
      method_arguments(self)
      return self.checker_
    end

    default_factory = function()

      return
      {
        checker = checker;
        --
        checker_ = make_checker();
      }
    end
  end

  local prototype_mt
  do
    local current_node_path_key = unique_object()

    local fail = function(self, msg)
      local path = self:get_current_node_path()
      local data = path[#path]

      if not data then
        -- TODO: ?!
        self:checker():fail("(???): " .. tostring(msg))
      else
        local where = ""
        if data.file_ and data.line_ then
          where = data.file_ .. ":" .. data.line_ .. ": "
        end

        self:checker():fail(
            where
         .. "bad " .. tostring(data[self.tag_field_]) .. " \""
         .. table_concat(
              self:get_current_node_path_readable(),
              self.node_path_separator_
            ) .. "\": "
         .. tostring(msg)
          )
      end

      return self
    end

    local ensure = function(self, msg, cond, err)
      if not cond then
        if not err then
          self:fail(msg)
        else
          self:fail(msg .. " (" .. tostring(err) .. ")")
        end
      end

      return self
    end

    local ensure_equals = function(self, msg, actual, expected)
      if actual ~= expected then
        self:fail(
            msg
         .. " (actual: `" .. tostring(actual)
         .. "', expected: `" .. tostring(expected)
         .. "')"
          )
      end

      return self
    end

    local good = function(self)
      method_arguments(self)
      return self:checker():good()
    end

    local result = function(self)
      method_arguments(self)
      return self:checker():result()
    end

    local get_current_node_path = function(self)
      local path = self[current_node_path_key]
      if path == nil then
        path = { }
        self[current_node_path_key] = path
      end
      return path
    end

    local get_current_node = function(self)
      local path = self:get_current_node_path()
      return path[#path]
    end

    local get_node_path_name = function(node, name_field, tag_field)
      local name = node[name_field]
      if not is_string(name) or #name > 32 then -- TODO: ?!
        name = nil
      end

      if not name then
        name = tostring(node[tag_field])
        if #name > 32 then
          name = name:sub(1, 29) .. "..."
        end

        name = "(" .. name .. ")"
      end

      return name
    end

    local get_current_node_path_readable = function(self)
      method_arguments(self)
      return timap(
          get_node_path_name,
          self:get_current_node_path(),
          self.name_field_,
          self.tag_field_
        )
    end

    local push_node_to_path = function(self, data)
      table_insert(self:get_current_node_path(), data)
    end

    local pop_node_from_path = function(self, data)
      local actual_node = table_remove(self:get_current_node_path())
      -- Note raw equality check
      if actual_node ~= data then
        log_error("current path:", self:get_current_node_path_readable())
        log_error(
            "tried to pop head",
            get_node_path_name(data, self.name_field_, self.tag_field_)
          )
        error("bad implementation: unbalanced path")
      end
    end

    prototype_mt =
    {
      fail = fail;
      ensure = ensure;
      ensure_equals = ensure_equals;
      --
      good = good;
      result = result;
      --
      get_current_node = get_current_node;
      get_current_node_path = get_current_node_path;
      get_current_node_path_readable = get_current_node_path_readable;
      push_node_to_path = push_node_to_path;
      pop_node_from_path = pop_node_from_path;
      --
      tag_field_ = "id";
      name_field_ = "name";
      node_path_separator_ = ".";
    }
    prototype_mt.__metatable = "twwc"
    prototype_mt.__index = prototype_mt
  end

  local wrap_down, wrap_up
  do
    wrap_down = function(handler)
      arguments("function", handler)

      return function(walkers, data, key)
        walkers:push_node_to_path(data)

        local result = handler(walkers, data, key)

        if result == "break" then
          walkers:pop_node_from_path(data)
        end

        return result
      end
    end

    wrap_up = function(handler)
      arguments("function", handler)

      return function(walkers, data, key)
        handler(walkers, data, key)

        walkers:pop_node_from_path(data)
      end
    end
  end

  local up = { }
  do
    up["walker:tag_field"] = function(self, data)
      assert(self.updown_.tag_field_ == nil, "duplicate tag field definition")
      self.updown_.tag_field_ = data.name
    end

    up["walker:name_field"] = function(self, data)
      assert(self.updown_.name_field_ == nil, "duplicate name field definition")
      self.updown_.name_field_ = data.name
    end

    up["walker:node_path_separator"] = function(self, data)
      assert(
          self.updown_.node_path_separator_ == nil,
          "duplicate node path separator field definition"
        )
      self.updown_.node_path_separator_ = data.name
    end

    up["walker:default_down"] = function(self, data)
      self:set_down_mt(assert_is_function(data.handler))
    end

    up["walker:default_up"] = function(self, data)
      self:set_up_mt(assert_is_function(data.handler))
    end

    up["walker:down"] = function(self, data)
      local name = data.name

      local down = self.updown_.down
      if rawget(down, data.name) ~= nil then
        error(
            "duplicate walker:down \"" .. tostring(data.name) .. "\" definition"
          )
      end

      down[data.name] = wrap_down(assert_is_function(data.handler))
    end

    up["walker:up"] = function(self, data)
      local name = data.name

      local up = self.updown_.up
      if rawget(up, data.name) ~= nil then
        error(
            "duplicate walker:up \"" .. tostring(data.name) .. "\" definition"
          )
      end

      up[data.name] = wrap_up(assert_is_function(data.handler))
    end

    up["walker:factory"] = function(self, data)
      assert_is_nil(self.factory_, "duplicate factory definition")
      self.factory_ = assert_is_function(data.handler)
    end
  end

  local set_down_mt, set_up_mt
  do
    local common_set_mt = function(t, handler, err, mt_name)
      arguments(
          "table", t,
          "function", handler,
          "string", err,
          "string", mt_name
        )

      assert(getmetatable(t) == nil, err)
      setmetatable(
          t,
          {
            __index = function(t, k)
              local v = handler
              t[k] = v
              return v
            end;
            __metatable = mt_name;
          }
        )
    end

    set_down_mt = function(self, handler)
      method_arguments(
          self,
          "function", handler
        )

      common_set_mt(
          self.updown_.down,
          wrap_down(handler),
          "duplicate default_down call",
          "twwc.updown.down"
        )
    end

    set_up_mt = function(self, handler)
      method_arguments(
          self,
          "function", handler
        )

      common_set_mt(
          self.updown_.up,
          wrap_up(handler),
          "duplicate default_up call",
          "twwc.updown.up"
        )
    end
  end

  local fail_at_unknown_down = function(self, data)
    -- TODO: Overhead! Move this check at metatable level.
    if not rawget(self.up, data[self.tag_field_]) then
      self:fail("unknown language construct")
      return "break" -- Do not traverse subtree
    end
  end

  create_tree_walker_with_checker_factory = function(chunk, extra_env)
    extra_env = extra_env or { }

    arguments(
        "function", chunk,
        "table", extra_env
      )

    local schema = common_load_schema(chunk, extra_env, { "walker" })

    local updown =
    {
      down = { };
      up = { };
    }
    updown.__index = updown
    updown.__metatable = "twwc.updown"

    local walkers =
    {
      up = up;
      --
      set_down_mt = set_down_mt;
      set_up_mt = set_up_mt;
      --
      updown_ = updown;
      factory_ = nil;
    }

    for i = 1, #schema do
      -- Note this "id" is not the same as the data tag_field.
      walk_tagged_tree(schema[i], walkers, "id")
    end

    if getmetatable(walkers.updown_.down) == nil then
      walkers:set_down_mt(fail_at_unknown_down)
    end

    if getmetatable(walkers.updown_.up) == nil then
      walkers:set_up_mt(do_nothing)
    end

    local factory = walkers.factory_ or default_factory
    local mt = setmetatable(updown, prototype_mt)

    return function(...)
      local result = factory(...)

      -- Your walker should provide checker() method.
      -- See default_factory() implementation.
      assert(result.down == nil, "bad twwc factory: down defined")
      assert(result.up == nil, "bad twwc factory: up defined")
      assert_is_function(result.checker, "bad twwc factory: missing walker")

      return setmetatable(result, mt)
    end
  end
end

--------------------------------------------------------------------------------

return
{
  create_tree_walker_with_checker_factory
    = create_tree_walker_with_checker_factory;
}
