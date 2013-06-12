--------------------------------------------------------------------------------
-- luabins_schema_builder.lua - build luabins schema
-- This file is a part of pk-engine library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------
--
-- WARNING: Quick hack. Not recommended to use.
--
--------------------------------------------------------------------------------

local log, dbg, spam, log_error = import 'pk-core/log.lua' { 'make_loggers' }(
    "luabins_schema_builder", "LSB"
  )

--------------------------------------------------------------------------------

local luabins = require 'luabins'

--------------------------------------------------------------------------------

local assert, pairs, ipairs, tostring = assert, pairs, ipairs, tostring

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

local is_string,
      is_number,
      is_function,
      is_table
      = import 'lua-nucleo/type.lua'
      {
        'is_string',
        'is_number',
        'is_function',
        'is_table'
      }

local lassert = import 'lua-nucleo/assert.lua' { 'lassert' }

local identity
      = import 'lua-nucleo/functional.lua'
      {
        'identity'
      }

local tijoin_many,
      tclone
      = import 'lua-nucleo/table.lua'
      {
        'tijoin_many',
        'tclone'
      }

local make_call_tracer = import 'pk-engine/call_tracer.lua' { 'make_call_tracer' }

--------------------------------------------------------------------------------

-- TODO: NOT for public consumption! Port to lua-aplicado.
-- TODO: Port to use method_arguments()

-- TODO: Reuse with form_handler_builder
local is_good_node_name = function(v)
  return true
end

-- TODO: Move more branching into building time.
--       Return different closures for each static branch.

-- TODO: What about key overrides?

local make_luabins_schema_builder
do
  local walk_schema = function(schema, dest, data)
    for i = 1, #schema do
      local res, err = (schema[i])(dest, data)
      if res == nil then
        return nil, "child "..i..": "..err
      end
    end
    return true
  end

  local getters =
  {
    [true] = function(t, key)
      return t[key]
    end;

    [false] = function(t, key)
      return t
    end;
  }

  local invariant_renderer = function(key, value)
    assert(key ~= nil)
    assert(value ~= nil)
    return function(dest, t)
      dest[key] = value
      return true
    end
  end

  local no_check = identity

  local raw_renderer = function(is_required, key)
    arguments(
        "boolean", is_required
      )
    -- key may be nil

    -- TODO: Lazy hack. Fix this limitation. Why there is no node_name here?!
    assert(key ~= nil)

    local getter = getters[key ~= nil]
    return function(dest, t)
      local v = getter(t, key)
      if v ~= nil then
        dest[key] = v
      elseif is_required then
        return nil, "node: missing reqired key " .. key
      end

      return true
    end
  end

  local attribute_renderer = function(
      is_required,
      key,
      node_name,
      filter,
      checker
    )
    arguments(
        "boolean", is_required,
        -- key may be nil,
        -- node_name is checked below,
        "function", filter,
        "function", checker
      )
    assert(is_good_node_name(node_name))

    local getter = getters[key ~= nil]
    return function(dest, t)
      local v = getter(t, key)
      if v ~= nil then
        -- Note this may set v to nil without returning err.
        -- This is wrong checker behaviour, but it is not checked against.
        local err
        v, err = checker(v)
        if err then
          return nil, "attribute: key " .. node_name .. " check failed: " .. err
        end
      end

      if v ~= nil then
        dest[node_name] = filter(v)
      elseif is_required then
        return nil, "attribute: missing reqired key " .. node_name
      end
      return true
    end
  end

  local node_renderer = function(is_required, key, node_name, schema)
    arguments(
        "boolean", is_required,
        -- key may be nil,
        -- node_name is checked below,
        "table", schema
      )
    assert(is_good_node_name(node_name))

    local getter = getters[key ~= nil]
    return function(dest, t, do_not_nest)
      local v = getter(t, key)
      if v ~= nil then
        local child
        if not do_not_nest then
          child = { }
        else
          child = dest
        end
        local res, err = walk_schema(schema, child, v)
        if res == nil then
          return nil, "node: " .. err
        end
        if not do_not_nest then -- TODO: WTF?! Used for list children
          dest[node_name] = child
        end
      elseif is_required then
        return nil, "node: missing reqired key " .. node_name
      end

      return true
    end
  end

  local cdata_renderer = function(is_required, key, nested_name)
    arguments(
        "boolean", is_required
        -- key may be nil,
        -- node_name is checked below,
        -- nested_name is checked below
      )
    if nested_name then assert(is_good_node_name(nested_name)) end
    assert(nested_name ~= nil or key ~= nil)

    local getter = getters[key ~= nil]
    return function(dest, t)
      local v = getter(t, key)
      if v ~= nil then
        dest[nested_name or key] = v
      elseif is_required then
        return nil, "cdata: missing reqired key " .. nested_name
      end

      return true
    end
  end

  local list_renderer = function(
      is_required,
      key,
      node_name,
      renderer,
      iterator,
      list_attribute_renderer
    )
    arguments(
        "boolean", is_required,
        -- key may be nil,
        -- node_name is checked below,
        "function", renderer,
        "function", iterator
      )
    assert(is_good_node_name(node_name))
    assert(not list_attribute_renderer or is_function(list_attribute_renderer))

    local getter = getters[key ~= nil]
    return function(dest, t)
      local v = getter(t, key)
      if v ~= nil then
        local list_node = { }

        if list_attribute_renderer then
          local res, err = list_attribute_renderer(list_node, t, true)
          if res == nil then
            return nil, 'list item attributes ' .. node_name .. ': ' .. err
          end
        end

        for k, v in iterator(v) do
          local child = { }
          local res, err = renderer(child, v, true)
          if res == nil then
            return nil, 'list item ' .. tostring(k) .. ': ' .. err
          end
          list_node[k] = child
        end
        dest[node_name] = list_node
      elseif is_required then
        return nil, "list: missing reqired key " .. node_name
      end

      return true
    end
  end

  -----------------------------------------------------------------------------

  -- TODO: Generalize to lua-nucleo as a family of check_is_* functions
  local check_is_number = function(v)
    if is_number(v) then
      return v
    end
    return nil, "numeric value required"
  end

  local make_raw_handler = function(is_required)
    arguments(
        "boolean", is_required
      )

    return function(self, key)
      method_arguments(
          self
        )
      -- key may be nil

      return raw_renderer(is_required, key)
    end
  end

  local raw = make_raw_handler(true)

  local optional_raw = make_raw_handler(false)

  local make_attribute_handler = function(is_required, filter, checker)
    arguments(
        "boolean", is_required,
        "function", filter,
        "function", checker
      )

    return function(self, key, node_name)
      node_name = node_name or key

      method_arguments(
          self
        )
      -- key may be nil
      lassert(2, is_good_node_name(node_name))

      local fn = attribute_renderer(
          is_required, key, node_name, filter, checker
        )
      self.attributes_[fn] = true
      return fn
    end
  end

  local const_attribute = function(self, node_name, value)
    method_arguments(
        self
        -- node_name is checked below,
        -- value may be of any non-nil type
      )
    lassert(2, is_good_node_name(node_name))
    assert(value ~= nil)

    local fn = invariant_renderer(node_name, value)
    self.attributes_[fn] = true
    return fn
  end

  local attribute = make_attribute_handler(true, identity, no_check)

  local optional_attribute = make_attribute_handler(
      false,
      identity,
      no_check
    )

  local numeric_attribute = make_attribute_handler(
      true, identity, check_is_number
    )

  local optional_numeric_attribute = make_attribute_handler(
      false, identity, check_is_number
    )

  local make_node_handler = function(is_required)
    arguments(
        "boolean", is_required
      )

    return function(self, key, node_name)
      node_name = node_name or key
      method_arguments(
          self
        )
      -- key may be nil
      lassert(2, is_good_node_name(node_name))

      local callid = self.calls_:push()
      return function(schema)
        arguments("table", schema)

        self.calls_:pop(callid)

        -- TODO: LAZY! Optimizeable.
        local attributes = { }
        local subnodes = { }

        for _, data in ipairs(schema) do
          if self.attributes_[data] then
            attributes[#attributes + 1] = data
          else
            subnodes[#subnodes + 1] = data
          end
        end

        if #subnodes > 0 then
          schema = tijoin_many(attributes, subnodes)
        else
          schema = attributes
        end

        return node_renderer(is_required, key, node_name, schema)
      end
    end
  end

  local node = make_node_handler(true)

  -- TODO: Made for list nodes, same as node now, remove?
  local list_node = node

  local optional_node = make_node_handler(false)

  local cdata = function(self, key) -- note no node_name
    method_arguments(self)
    -- key may be nil

    return cdata_renderer(true, key, nil)
  end

  local optional_cdata = function(self, key) -- note no node_name
    method_arguments(self)
    -- key may be nil

    return cdata_renderer(false, key, nil)
  end

  local named_cdata = function(self, key, node_name)
    node_name = node_name or key
    method_arguments(self)
    -- key may be nil
    lassert(2, is_good_node_name(node_name))

    return cdata_renderer(true, key, node_name)
  end

  local optional_named_cdata = function(self, key, node_name)
    node_name = node_name or key
    method_arguments(self)
    -- key may be nil
    lassert(2, is_good_node_name(node_name))

    return cdata_renderer(false, key, node_name)
  end

  -- A helper function
  local make_list_handler = function(is_required, iterator, can_have_attributes)
    if can_have_attributes == nil then can_have_attributes = false end
    arguments(
        "boolean", is_required,
        "function", iterator,
        "boolean", can_have_attributes
      )

    return function(self, key, node_name)
      node_name = node_name or key
      method_arguments(self)
      -- key may be nil
      lassert(2, is_good_node_name(node_name))

      local callid = self.calls_:push()
      return function(renderer_or_schema)
        local list_attribute_renderer = nil
        local renderer = renderer_or_schema
        if is_table(renderer_or_schema) then
          local num_children = #renderer_or_schema
          renderer = renderer_or_schema[num_children]
          if can_have_attributes and num_children > 1 then
            local schema = tclone(renderer_or_schema)
            schema[num_children] = nil
            list_attribute_renderer = node_renderer(
                is_required,
                key,
                node_name,
                schema
              )
          end
        end
        arguments(
            "function", renderer
          )

        self.calls_:pop(callid)

        return list_renderer(
            is_required, key, node_name, renderer,
            iterator, list_attribute_renderer
          )
      end
    end
  end

  local list = make_list_handler(true, pairs)

  local ilist = make_list_handler(true, ipairs, true)

  local optional_list = make_list_handler(false, pairs)

  local optional_ilist = make_list_handler(false, ipairs, true)

  -- TODO: Implement correct realization, must output keys somehow!
  local dictionary = make_list_handler(true, pairs)

  -- TODO: Implement correct realization, must output keys somehow!
  local optional_dictionary = make_list_handler(false, pairs)

  local commit = function(self, data)
    method_arguments(
        self,
        "function", data
      )

    if not self.calls_:empty() then
      error("dangling builder call detected:\n"..self.calls_:dump())
    end

    self.attributes_ = {}

    return function(t)
      arguments(
          "table", t
        )

      local dest = { }
      local res, err = data(dest, t)
      if res ~= nil then
        res, err = luabins.save(dest)
      end
      return res, err
    end
  end

  make_luabins_schema_builder = function()
    return
    {
      raw = raw;
      optional_raw = optional_raw;
      --
      const_attribute = const_attribute;
      --
      attribute = attribute;
      optional_attribute = optional_attribute;
      --
      numeric_attribute = numeric_attribute;
      optional_numeric_attribute = optional_numeric_attribute;
      --
      node = node;
      list_node = list_node;
      optional_node = optional_node;
      --
      cdata = cdata;
      optional_cdata = optional_cdata;
      --
      named_cdata = named_cdata;
      optional_named_cdata = optional_named_cdata;
      --
      list = list;
      optional_list = optional_list;
      --
      ilist = ilist;
      optional_ilist = optional_ilist;
      --
      dictionary = dictionary;
      optional_dictionary = optional_dictionary;
      --
      commit = commit;
      --
      calls_ = make_call_tracer();
      attributes_ = { };
    }
  end
end

--------------------------------------------------------------------------------

return
{
  make_luabins_schema_builder = make_luabins_schema_builder;
}
