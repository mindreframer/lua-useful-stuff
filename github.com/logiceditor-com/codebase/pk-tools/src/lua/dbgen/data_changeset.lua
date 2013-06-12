--------------------------------------------------------------------------------
-- data_changeset.lua: data changeset generator
-- This file is a part of pk-tools library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------

local uuid = require 'uuid'

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
      timap
      = import 'lua-nucleo/table.lua'
      {
        'empty_table',
        'timap'
      }

local make_concatter
      = import 'lua-nucleo/string.lua'
      {
        'make_concatter'
      }


local find_all_files
      = import 'lua-aplicado/filesystem.lua'
      {
        'find_all_files'
      }

local make_loggers
      = import 'pk-core/log.lua'
      {
        'make_loggers'
      }

local make_enquirer
      = import 'pk-engine/db/enquirer.lua'
      {
        'make_enquirer'
      }

local format_changeset
      = import 'dbgen/changeset.lua'
      {
        'format_changeset'
      }

local update_changesets
      = import 'dbgen/update_changes.lua'
      {
        'update_changesets'
      }

local make_config_manager
      = import 'pk-engine/srv/internal_config/client.lua'
      {
        'make_config_manager'
      }

local make_db_connection_manager
      = import 'pk-engine/db/db_connection_manager.lua'
      {
        'make_db_connection_manager'
      }

local make_db_manager
      = import 'pk-engine/db/db_manager.lua'
      {
        'make_db_manager'
      }

--------------------------------------------------------------------------------

local log, dbg, spam, log_error = make_loggers("data_changeset", "DCH")

--------------------------------------------------------------------------------

local render_inserts = function(table_name, primary_key, list, escaper)
  assert(#list > 0)

  local cat, concat = make_concatter()

  cat [[INSERT INTO `]] (table_name) [[` (]]

  -- TODO: Take key order from db.lua?
  local keys = { }
  for k, _ in pairs(list[1]) do -- WARNING: Assuming uniform key structure!
    if #keys > 0 then
      cat([[,]])
    end
    cat [[`]] (k) [[`]]

    keys[#keys + 1] = k
  end

  cat [[)]] ("\n") [[VALUES]] ("\n")

  for i = 1, #list do
    if i > 1 then
      cat [[,]] ("\n")
    end
    cat [[  (]]

    local item = list[i]
    for i = 1, #keys do
      local value = item[keys[i]]
      assert(value ~= nil)

      if i > 1 then
        cat [[, ]]
      end

      -- Extra protection from binary data to make Lua happier
      -- TODO: Check if this handles quotes in string properly
      --       It should insert them intact
      cat [[']] (escaper:escape(value)) [[']]
    end

    cat [[)]]
  end

  return concat()
end

local render_deletes = function(table_name, primary_key, ids, escaper)
  assert(#ids > 0)

  -- TODO: Should be multiline
  return [[DELETE FROM `]] .. table_name .. [[`]]
    .. [[ WHERE 1 AND ]]
    .. [[`]] .. primary_key .. [[` IN (]]
    .. table.concat(ids, [[,]])
    .. [[) LIMIT ]] .. #ids
end

--------------------------------------------------------------------------------

local make_fancier_db_escaper = function(db_conn)
end

--------------------------------------------------------------------------------

-- TODO: Need to do lock table etc.
local generate_data_changeset = function(
    db_manager,
    table_name,
    ignore_in_tests,
    tables
  )
  arguments(
      "table", db_manager,
      "string", table_name,
      "boolean", ignore_in_tests,
      "table", tables
    )

  local table_info = assert(tables[table_name])

  local DB_NAME = assert_is_string(table_info.db_name)
  local UUID = DB_NAME .. "/"
    .. table_name .. "/"
    .. "data/" -- TODO: Make configurable?
    .. uuid.new()

  local db_conn, conn_id = db_manager:acquire_db_connection(DB_NAME)

  local enquirer = make_enquirer(
      table_info.table,
      table_info.primary_key,
      table_info.features
    )

  local list = assert(enquirer:list(db_conn))

  assert(#list > 0, "table is empty")

  local ids = { }
  for i = 1, #list do
    ids[#ids + 1] = assert(list[i][table_info.primary_key])
  end

  -- Padding to match indentation
  local insert_list = render_inserts(
      table_info.table,
      table_info.primary_key,
      list,
      db_conn
    ):gsub("\n(.)", "\n    %1")

  -- Padding to match indentation
  local remove_ids = render_deletes(
      table_info.table,
      table_info.primary_key,
      ids,
      db_conn
    ):gsub("\n(.)", "\n    %1")

  db_manager:unacquire_db_connection(db_conn, conn_id)

  return
  {
    table_name = assert_is_string(table_name);
    data =
    {
      ignore_in_tests = ignore_in_tests;
      --
      DB_NAME = DB_NAME;
      UUID = UUID;

      apply = [=[
function(db_conn)
  return db_conn:execute [[
    ]=] .. insert_list .. [=[

  ]]
end
]=];

      revert = [=[
function(db_conn)
  return db_conn:execute [[
    ]=] .. remove_ids .. [=[

  ]]
end
]=];
    };
  }
end

--------------------------------------------------------------------------------

local update_data_changeset = function(
    config_host,
    config_port,
    table_name,
    out_dir,
    force,
    ignore_in_tests,
    tables
  )
  arguments(
      "string", config_host,
      "number", config_port,
      "string", table_name,
      "string", out_dir,
      "boolean", force,
      "boolean", ignore_in_tests,
      "table", tables
    )

  local config_manager = assert(make_config_manager(config_host, config_port))
  local db_manager = assert(
      make_db_manager(
          config_manager,
          make_db_connection_manager()
        )
    )

  -- A single changeset actually
  local new_changesets =
  {
    generate_data_changeset(db_manager, table_name, ignore_in_tests, tables);
  }

  update_changesets(new_changesets, out_dir, force, "data")
end

--------------------------------------------------------------------------------

return
{
  update_data_changeset = update_data_changeset;
}
