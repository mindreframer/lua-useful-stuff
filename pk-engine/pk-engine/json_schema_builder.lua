--------------------------------------------------------------------------------
-- json_schema_builder.lua - build xml schema
-- This file is a part of pk-engine library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------

local log, dbg, spam, log_error = import 'pk-core/log.lua' { 'make_loggers' }(
    "json_schema_builder.lua", "JSB"
  )

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

local escape_for_json
      = import 'lua-nucleo/string.lua'
      {
        'escape_for_json'
      }

local make_call_tracer = import 'pk-engine/call_tracer.lua' { 'make_call_tracer' }

-- TODO: NOT for public consumption! Port to lua-nucleo.
-- TODO: Port to use method_arguments()
-- NOTE: Based on xml_schema_builder.

-- TODO: Reuse with form_handler_builder
local is_good_node_name = function(v)
  if not is_string(v) then
    return nil, "node/attribute name must be a string"
  end

  if not v:find("^[a-zA-Z_][:%-_0-9a-zA-Z]*$") then -- TODO: Refine this
    return nil, "invalid characters detected in node/attribute name"
  end

  return true
end

local js_escape_num = function(value)
  if is_number(value) then
    return tostring(value)
  end
  return escape_for_json(value)
end

-- TODO: Why numbers are acceptable here?
local js_escape = js_escape_num

-- TODO: Move more branching into building time.
--       Return different closures for each static branch.

local make_json_schema_builder
do
  local walk_schema = function(schema, cat, data)
    local was_at_least_one_output = false
    local was_output = false
    for i = 1, #schema do
      if was_output then
        cat.pre = ","
      end
      local res, err = (schema[i])(cat, data)
      if res == nil then
        return nil, "child "..i..": "..err
      end
      was_output = res;
      was_at_least_one_output = was_at_least_one_output or was_output
    end
    cat.pre = ""
    return was_at_least_one_output
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

  local invariant_renderer = function(str)
    arguments(
        "string", str
      )
    return function(cat, t)
      cat.add(str)
      return true
    end
  end

  local no_check = identity

  local raw_renderer = function(is_required, key)
    arguments(
        "boolean", is_required
      )
    -- key may be nil

    local getter = getters[key ~= nil]
    return function(cat, t)
      local was_output = false
      local v = getter(t, key)
      if v ~= nil then
        cat.add(v)
        was_output = true
      elseif is_required then
        return nil, "node: missing reqired key " .. key
      end
      return was_output
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
    return function(cat, t)
      local was_output = false
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
        cat.add '"' (node_name) '":' (filter(v))
        was_output = true
      elseif is_required then
        return nil, "attribute: missing reqired key " .. node_name
      end
      return was_output
    end
  end

  local node_renderer = function(is_required, key, node_name, schema, is_anonymous)
    arguments(
        "boolean", is_required,
        -- key may be nil,
        -- node_name is checked below,
        "table", schema,
        "boolean", is_anonymous
      )
    assert(is_good_node_name(node_name))

    local getter = getters[key ~= nil]
    return function(cat, t, caption_renderer)
      local v = getter(t, key)
      local was_output = false
      if v ~= nil then
        if caption_renderer then
          caption_renderer(node_name)
          was_output = true
        elseif not is_anonymous then
          cat.add '"' (node_name) '":{'
          was_output = true
        end
        local res, err = walk_schema(schema, cat, v)
        if res == nil then
          return nil, "node: " .. err
        end
        was_output = was_output or res
        if caption_renderer then
          -- Nothing to do
        elseif not is_anonymous then
          cat.add '}'
          was_output = true
        end
      elseif is_required then
        return nil, "node: missing reqired key " .. node_name
      end
      return was_output
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

    local getter = getters[key ~= nil]
    return function(cat, t)
      local was_output = false
      local v = getter(t, key)
      if v ~= nil then
        if nested_name then
          cat.add '"' (nested_name) '":'
        end
        cat.add (js_escape(v))
        if nested_name then
          -- Note: Nothing to do
        end
        was_output = true
      elseif is_required then
        return nil, "cdata: missing reqired key " .. nested_name
      end
      return was_output
    end
  end

  local list_renderer = function(
      is_required,
      key,
      node_name,
      renderer,
      iterator,
      render_with_keys,
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
    return function(cat, t)
      local was_output = false
      local v = getter(t, key)
      if v ~= nil then
        cat.add '"' (node_name) '":{'

        if list_attribute_renderer then
          local res, err = list_attribute_renderer(cat,t,false)
          if res == nil then
            return nil, 'list item attributes ' .. node_name .. ': ' .. err
          end
          if res then
            cat.pre = ','
          end
        end

        local was_at_least_one_element = false
        local not_first
        for k, v in iterator(v) do
          was_at_least_one_element = true
          local caption_renderer = nil

          if not_first then
            cat.pre = ","
            if not render_with_keys then
              cat.add "{"
            else
              caption_renderer = function(name)
                cat.add '"' (k) '":{'
              end
            end
          else
            not_first = true
            if not render_with_keys then
              caption_renderer = function(name)
                cat.add '"' (name) '":[{'
              end
            else
              caption_renderer = function(name)
                cat.add '"' (name) '":{' '"' (k) '":{'
              end
            end
          end

          local res, err = renderer(cat, v, caption_renderer)
          cat.add "}"
          if res == nil then
            return nil, 'list item '..tostring(k)..': '..err
          end
        end
        cat.pre = nil
        if was_at_least_one_element then
          if not render_with_keys then
            cat.add ']'
          else
            cat.add '}'
          end
        end
        cat.add '}'
        was_output = true
      elseif is_required then
        return nil, "list: missing reqired key " .. node_name
      end

      return was_output
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

      local fn = attribute_renderer(is_required, key, node_name, filter, checker)
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

    local fn = invariant_renderer(
        '"'..node_name..'":'..js_escape(tostring(value))
      )
    self.attributes_[fn] = true
    return fn
  end

  local attribute = make_attribute_handler(true, js_escape_num, no_check)

  local optional_attribute = make_attribute_handler(false, js_escape_num, no_check)

  local numeric_attribute = make_attribute_handler(true, identity, check_is_number)

  local optional_numeric_attribute = make_attribute_handler(false, identity, check_is_number)

  local make_node_handler = function(is_required, is_anonymous)
    arguments(
        "boolean", is_required,
        "boolean", is_anonymous
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
        local attributes = {}
        local subnodes = {}

        -- TODO: WTF?! Remove these XML-isms ASAP!
        for _, data in ipairs(schema) do
          if self.attributes_[data] then
            attributes[#attributes + 1] = data
          else
            subnodes[#subnodes + 1] = data
          end
        end

        -- TODO: WTF?! Remove these XML-isms ASAP!
        if #subnodes > 0 then
          schema = tijoin_many(attributes, subnodes)
        else
          schema = attributes
        end

        return node_renderer(is_required, key, node_name, schema, is_anonymous)
      end
    end
  end

  local node = make_node_handler(true, false)

  -- TODO: Small hack?
  local list_node = make_node_handler(true, true)

  local optional_node = make_node_handler(false, false)

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

  --Note: Anonymous fields are prhibited in json
  local cdata = named_cdata;
  local optional_cdata = optional_named_cdata;

  -- A helper function
  local make_list_handler = function(
      is_required, iterator, can_have_attributes, render_with_keys
    )
    if can_have_attributes == nil then can_have_attributes = false end
    if render_with_keys == nil then render_with_keys = false end
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
            list_attribute_renderer = node_renderer(is_required, key, node_name, schema, true)
          end
        end
        arguments(
            "function", renderer
          )

        self.calls_:pop(callid)

        return list_renderer(
            is_required, key, node_name, renderer,
            iterator, render_with_keys, list_attribute_renderer
          )
      end
    end
  end

  local list = make_list_handler(true, pairs)

  local ilist = make_list_handler(true, ipairs, true)

  local optional_list = make_list_handler(false, pairs)

  local optional_ilist = make_list_handler(false, ipairs, true)

  local dictionary = make_list_handler(true, pairs, false, true)

  local optional_dictionary = make_list_handler(false, pairs, false, true)

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

      local buf = {}

      local cat
      do
        cat = { pre = nil; add = nil }
        cat.add = function(v)
          if cat.pre then buf[#buf + 1] = tostring(cat.pre) cat.pre = nil end
          buf[#buf + 1] = tostring(v)
          return cat.add
        end
      end

      cat.add "{"
      local res, err = data(cat, t)
      if res ~= nil then
        cat.add "}"
        res = table.concat(buf)
      end
      return res, err
    end
  end

  make_json_schema_builder = function()
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
      attributes_ = {};
    }
  end
end

return
{
  make_json_schema_builder = make_json_schema_builder;
}
