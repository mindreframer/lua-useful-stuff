--------------------------------------------------------------------------------
-- common_load_schema.lua: common dsl schema loader
-- This file is a part of pk-core library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------
-- Sandbox warning: alias all globals!
--------------------------------------------------------------------------------

local debug_traceback, debug_getinfo = debug.traceback, debug.getinfo

local assert, error, pairs, rawset, setfenv
    = assert, error, pairs, rawset, setfenv

local setmetatable, tostring, xpcall, select
    = setmetatable, tostring, xpcall, select

--------------------------------------------------------------------------------

local log, dbg, spam, log_error
      = import 'pk-core/log.lua' { 'make_loggers' } (
          "common_load_schema", "CLS"
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

local is_table,
      is_function
      = import 'lua-nucleo/type.lua'
      {
        'is_table',
        'is_function'
      }

local assert_is_table
      = import 'lua-nucleo/typeassert.lua'
      {
        'assert_is_table'
      }

local tset,
      torderedset,
      torderedset_insert,
      torderedset_remove,
      tivalues,
      twithdefaults
      = import 'lua-nucleo/table-utils.lua'
      {
        'tset',
        'torderedset',
        'torderedset_insert',
        'torderedset_remove',
        'tivalues',
        'twithdefaults'
      }

local make_dsl_loader
      = import 'pk-core/dsl_loader.lua'
      {
        'make_dsl_loader'
      }

--------------------------------------------------------------------------------

-- TODO: Lazy! Do not create so many closures!
local common_load_schema -- TODO: Generalize more. Apigen uses similar code.
do
  common_load_schema = function(
      chunks,
      extra_env,
      allowed_namespaces,
      need_file_line
    )
    if is_function(chunks) then
      chunks = { chunks }
    end

    extra_env = extra_env or { }
    arguments(
        "table", chunks,
        "table", extra_env
      )
    optional_arguments(
        "table", allowed_namespaces,
        "boolean", need_file_line -- TODO: Hack. Not generic enough
      )
    if allowed_namespaces then
      allowed_namespaces = tset(allowed_namespaces)
    end

    local positions = torderedset({ })
    local unhandled_positions = { }
    local soup = { }

    local make_common_loader = function(namespace)
      arguments("string", namespace)

      local name_filter = function(tag, name, ...)
        assert(select("#", ...) == 0, "extra arguments are not supported")

        local data

        if is_table(name) then -- data-only-call
          -- Allowing data.name to be missing.
          data = name
        elseif is_function(name) then -- handler-only-call
          -- Allowing data.name to be missing.
          data =
          {
            handler = name;
          }
        else -- normal named call
          data =
          {
            name = name;
          }
        end

        data.tag = tag
        data.namespace = namespace;
        data.id = namespace .. ":" .. tag

        -- Calls to debug.getinfo() are slow,
        -- so we're not doing them by default.
        if need_file_line then
          -- TODO: Hack. Depth level is too dependent on the dsl_loader
          --       internals. Better to traverse stack until schema is found.
          local info = debug_getinfo(3, "Sl")
          data.source_ = info.source
          data.file_ = info.short_src
          data.line_ = info.currentline
        end

        torderedset_insert(positions, data)
        unhandled_positions[data] = positions[data]

        return data
      end

      local data_filter = function(name_data, value_data)
        assert_is_table(name_data)

        -- A special case for handler-only named tags
        if is_function(value_data) then
          value_data =
          {
            handler = value_data;
          }
        end

        -- Letting user to override any default values (including name and tag)
        local data = twithdefaults(value_data, name_data)

        local position = assert(positions[name_data])
        assert(soup[position] == nil)
        soup[position] = data

        -- Can't remove from set, need id to be taken
        unhandled_positions[name_data] = nil

        return data
      end

      return make_dsl_loader(name_filter, data_filter)
    end

    local loaders = { }

    local environment = setmetatable(
        { },
        {
          __index = function(t, namespace)
            -- Can't put it as setmetatable first argument -- 
            -- we heavily change that table afterwards.
            local v = extra_env[namespace]
            if v ~= nil then
              return v
            end

            -- TODO: optimizable. Employ metatables.
            if allowed_namespaces and not allowed_namespaces[namespace] then
              error(
                  "attempted to read from global `"
               .. tostring(namespace) .. "'",
                  2
                )
            end

            local loader = make_common_loader(namespace)
            loaders[namespace] = loader

            local v = loader:get_interface()
            rawset(t, namespace, v)
            return v
          end;

          __newindex = function(t, k, v)
            error("attempted to write to global `" .. tostring(k) .. "'", 2)
          end;
        }
      )

    for i = 1, #chunks do
      local chunk = chunks[i]

      -- TODO: Restore chunk environment?
      setfenv(
          chunk,
          environment
        )

      assert(
          xpcall(
              chunk,
              function(err)
                log_error("failed to load schema:\n" .. debug_traceback(err))
                return err
              end
            )
        )
    end

    -- For no-name top-level tags
    for data, position in pairs(unhandled_positions) do
      assert(soup[position] == nil)
      soup[position] = data
    end

    assert(#soup > 0, "no data in schema")

    for _, loader in pairs(loaders) do
      soup = loader:finalize_data(soup)
    end

    -- TODO: OVERHEAD! Try to get the list of top-level nodes from dsl_loader.
    soup = torderedset(soup)

    local function unsoup(soup, item)
      for k, v in pairs(item) do
        if is_table(k) then
          torderedset_remove(soup, k)
          unsoup(soup, k)
        end
        if is_table(v) then
          torderedset_remove(soup, v)
          unsoup(soup, v)
        end
      end

      return soup
    end

    local values = tivalues(soup) -- TODO: Hack. Workaround for torderedset changing value order

    local n_soup = #values
    for i = 1, n_soup do
      unsoup(soup, values[i])
    end

    local schema = tivalues(soup) -- Get rid of the set part

    return schema
  end
end

--------------------------------------------------------------------------------

return
{
  common_load_schema = common_load_schema;
}
