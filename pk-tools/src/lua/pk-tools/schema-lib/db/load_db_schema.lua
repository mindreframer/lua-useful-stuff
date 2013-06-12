--------------------------------------------------------------------------------
-- load_db_schema.lua: db schema loader
-- This file is a part of pk-tools library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------

local arguments,
      optional_arguments,
      method_arguments,
      eat_true
      = import 'lua-nucleo/args.lua'
      {
        'arguments',
        'optional_arguments',
        'method_arguments',
        'eat_true'
      }

local is_table
      = import 'lua-nucleo/type.lua'
      {
        'is_table'
      }

local assert_is_table,
      assert_is_number,
      assert_is_string
      = import 'lua-nucleo/typeassert.lua'
      {
        'assert_is_table',
        'assert_is_number',
        'assert_is_string'
      }

local empty_table,
      timap,
      torderedset,
      torderedset_insert,
      twithdefaults
      = import 'lua-nucleo/table-utils.lua'
      {
        'empty_table',
        'timap',
        'torderedset',
        'torderedset_insert',
        'twithdefaults'
      }

local make_loggers
      = import 'pk-core/log.lua'
      {
        'make_loggers'
      }

local make_dsl_loader
      = import 'pk-core/dsl_loader.lua'
      {
        'make_dsl_loader'
      }

--------------------------------------------------------------------------------

local log, dbg, spam, log_error = make_loggers("load_db_schema", "LDS")

--------------------------------------------------------------------------------

local load_db_schema = function(filename)
  local tables = { }

  do
    local current_database = false

    local positions = torderedset({ })

    local name_filter = function(tag, name, ...)
      assert(select("#", ...) == 0, "extra arguments are not supported")

      local data

      if is_table(name) then
        data = name
      else
        data = { name = name }
      end

      data.tag = tag

      if tag == "database" then
        current_database = assert_is_string(name)
      elseif tag == "table" then
        if not current_database then
          error("sql:database missing before `" .. name .. "'", 2)
        end

        data.db_name = current_database

        if data.singular_name == nil then
          if data.name:sub(-1) == "s" and #data.name > 1 then
            data.singular_name = data.name:sub(1, -2)
          elseif data.name:find("s_[a-z]-y$") then -- TODO: ?! Too arbitrary?
            data.singular_name = data.name:gsub("s(_[a-z]-y)$", "%1")
          elseif data.name:find("[^s]_info$") then -- TODO: ?! Too arbitrary?
            data.singular_name = data.name
          elseif not data.name:find("s") then
            data.singular_name = data.name -- TODO: ?! Arguable.
          end
        end

        torderedset_insert(positions, name)
      end

      return data
    end

    local data_filter = function(name_data, value_data)
      -- Letting user to override any default values (including name and tag)
      local data = twithdefaults(value_data, name_data)

      if data.tag == "table" then
        tables[positions[data.name]] = data
      end

      return data
    end

    local dsl_loader = make_dsl_loader(name_filter, data_filter)
    local sql = dsl_loader:get_interface()

    log("loading db schema from", filename)

    local chunk = assert(loadfile(filename))
    setfenv(
        chunk,
        setmetatable(
            {
              import = import; -- This is a trusted sandbox
              sql = sql;
            },
            {
              __index = function(t, k)
                error("attempted to read global `" .. tostring(k) .. "'", 2)
              end;

              __newindex = function(t, k, v)
                error("attempted to write to global `" .. tostring(k) .. "'", 2)
              end;
            }
          )
      )

    assert(
        xpcall(
            chunk,
            function(err)
              log_error("failed to load DSL data:\n"..debug.traceback(err))
              return err
            end
          )
      )

    tables = dsl_loader:finalize_data(tables)
  end

  return tables
end

--------------------------------------------------------------------------------

return
{
  load_db_schema = load_db_schema;
}
