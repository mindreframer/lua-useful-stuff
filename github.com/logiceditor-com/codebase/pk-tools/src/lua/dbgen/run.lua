--------------------------------------------------------------------------------
-- run.lua: database stuff generator
-- This file is a part of pk-tools library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------
-- TODO: Table name validation should take database name in account.
--       But make autotests support different databases before fixing that.
--       Also update changes naming scheme to include database name.
--------------------------------------------------------------------------------

local lfs = require 'lfs'

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
      tkeys,
      tset
      = import 'lua-nucleo/table.lua'
      {
        'empty_table',
        'timap',
        'tkeys',
        'tset'
      }

local make_loggers
      = import 'pk-core/log.lua'
      {
        'make_loggers'
      }

local update_file,
      write_file
      = import 'lua-aplicado/filesystem.lua'
      {
        'update_file',
        'write_file'
      }

local load_db_schema
      = import 'pk-tools/schema-lib/db/load_db_schema.lua'
      {
        'load_db_schema'
      }

local validate_db_schema
      = import 'pk-tools/schema-lib/db/schema-validator.lua'
      {
        'validate_db_schema'
      }

local convert_db_schema_to_dot
      = import 'dbgen/dot.lua'
      {
        'convert_db_schema_to_dot'
      }

local convert_db_schema_to_changesets,
      update_changesets
      = import 'dbgen/update_changes.lua'
      {
        'convert_db_schema_to_changesets',
        'update_changesets'
      }

local generate_db_tables
      = import 'dbgen/db-tables.lua'
      {
        'generate_db_tables'
      }

local generate_db_tables_test_data
      = import 'dbgen/db-tables-test-data.lua'
      {
        'generate_db_tables_test_data'
      }

local update_data_changeset
      = import 'dbgen/data_changeset.lua'
      {
        'update_data_changeset'
      }

local load_tools_cli_data_schema,
      load_tools_cli_config,
      print_tools_cli_config_usage,
      freeform_table_value
      = import 'pk-core/tools_cli_config.lua'
      {
        'load_tools_cli_data_schema',
        'load_tools_cli_config',
        'print_tools_cli_config_usage',
        'freeform_table_value'
      }

local tpretty
      = import 'lua-nucleo/tpretty.lua'
      {
        'tpretty'
      }

local create_config_schema
      = import 'dbgen/project-config/schema.lua'
      {
        'create_config_schema',
      }

--------------------------------------------------------------------------------

local log, dbg, spam, log_error = make_loggers("dbgen", "DGE")

--------------------------------------------------------------------------------

-- NOTE: Generation requires fixed random seed for consistency
math.randomseed(12345)

--------------------------------------------------------------------------------

local update_changes = function(tables, out_dir, force, ignore_in_tests)
  local changesets = convert_db_schema_to_changesets(tables)
  update_changesets(changesets, out_dir, force, "create", ignore_in_tests)
end

local update_tables = function(tables, out_filename, force)
  local new_data = generate_db_tables(tables)

  -- TODO: ?!
  local res, err = update_file(out_filename, new_data, force)
  if not res then
    log_error("WARNING:", err)
    log("Continuing with override")
    update_file(out_filename, new_data, true)
  end

  log("OK")
end

local update_tables_test_data = function(tables, out_filename, force)
  local new_data = generate_db_tables_test_data(tables)

  -- TODO: ?!
  local res, err = update_file(out_filename, new_data, force)
  if not res then
    log_error("WARNING:", err)
    log("Continuing with override")
    update_file(out_filename, new_data, true)
  end

  log("OK")
end

--------------------------------------------------------------------------------

local SCHEMA = create_config_schema()

local EXTRA_HELP, CONFIG, ARGS

--------------------------------------------------------------------------------

local ACTIONS = { }

ACTIONS.help = function()
  print_tools_cli_config_usage(EXTRA_HELP, SCHEMA)
end

ACTIONS.check_config = function()
  io.stdout:write("config OK\n")
  io.stdout:flush()
end

ACTIONS.dump_config = function()
  io.stdout:write(tpretty(freeform_table_value(CONFIG), " ", 80), "\n")
  io.stdout:flush()
end

ACTIONS.check = function()
  local db_schema_filename = CONFIG.common.db.schema_filename

  local tables = load_db_schema(db_schema_filename)
  validate_db_schema(tables)
end

ACTIONS.dottify = function()
  local db_schema_filename = CONFIG.common.db.schema_filename
  local dot_out_filename = CONFIG.common.db.generated_dot_filename
  local pdf_out_filename = CONFIG.common.db.generated_pdf_filename

  local tables = load_db_schema(db_schema_filename)
  validate_db_schema(tables)

  log("dottifying db schema", db_schema_filename, "to", dot_out_filename)
  assert(write_file(dot_out_filename, convert_db_schema_to_dot(tables)))

  log("generating pdf for", dot_out_filename, "to", pdf_out_filename)
  assert(
      os.execute(
          "dot '" .. dot_out_filename .. "' -Tpdf -o '"
       .. pdf_out_filename .."'"
        ) == 0
    )
end

ACTIONS.update_changes = function()
  local db_schema_filename = CONFIG.common.db.schema_filename
  local force = CONFIG.dbgen.action.param.force

  -- Remove trailing slashes
  local changes_dir = CONFIG.common.db.changes_dir:gsub("/+$", "")

  log(
      "updating changes for db schema", db_schema_filename,
      "in", changes_dir .. "/"
    )

  local tables = load_db_schema(db_schema_filename)
  validate_db_schema(tables)

  update_changes(tables, changes_dir, force)
end

ACTIONS.update_tables = function()
  local db_schema_filename = CONFIG.common.db.schema_filename
  local force = CONFIG.dbgen.action.param.force
  local tables_filename = CONFIG.common.db.tables_filename

  log(
      "updating tables.lua for db schema", db_schema_filename,
      "in", tables_filename
    )

  local tables = load_db_schema(db_schema_filename)
  validate_db_schema(tables)

  update_tables(tables, tables_filename, force)
end

ACTIONS.update_tables_test_data = function()
  local db_schema_filename = CONFIG.common.db.schema_filename
  local force = CONFIG.dbgen.action.param.force
  local tables_test_data_filename = CONFIG.common.db.tables_test_data_filename

  log(
      "updating tables-test-data.lua for db schema", db_schema_filename,
      "in", tables_test_data_filename
    )

  local tables = load_db_schema(db_schema_filename)
  validate_db_schema(tables)

  update_tables_test_data(tables, tables_test_data_filename, force)
end

ACTIONS.update_db = function()
  local db_schema_filename = CONFIG.common.db.schema_filename
  local force = CONFIG.dbgen.action.param.force
  local tables_filename = CONFIG.common.db.tables_filename
  local tables_test_data_filename = CONFIG.common.db.tables_test_data_filename

  -- Remove trailing slashes
  local changes_dir = CONFIG.common.db.changes_dir:gsub("/+$", "")

  log(
      "updating files for db schema", db_schema_filename,
      "in changes:", changes_dir .. "/", ",",
      "tables:", tables_filename, ",",
      "and tables-test-data:", tables_test_data_filename
    )

  local tables = load_db_schema(db_schema_filename)
  validate_db_schema(tables)

  update_changes(tables, changes_dir, force, false)
  update_tables(tables, tables_filename, force)
  update_tables_test_data(tables, tables_test_data_filename, force)

  log("DB successfully updated")
end

-- TODO: Does it belong here?
ACTIONS.update_data_changeset = function()
  local db_schema_filename = CONFIG.common.db.schema_filename
  local config_host = CONFIG.common.internal_config.deploy.host
  local config_port = CONFIG.common.internal_config.deploy.port
  local force = CONFIG.dbgen.action.param.force
  local table_name = CONFIG.dbgen.action.param.table_name
  local ignore_in_tests = CONFIG.dbgen.action.param.ignore_in_tests
  local tables_filename = CONFIG.common.db.tables_filename

  -- Remove trailing slashes
  local changes_dir = CONFIG.common.db.changes_dir:gsub("/+$", "")

  log(
      "updating data changeset for table", table_name,
      "in", changes_dir
    )

  update_data_changeset(
      config_host,
      config_port,
      table_name,
      changes_dir,
      force,
      ignore_in_tests,
      import (tables_filename) ()
    )
end

--------------------------------------------------------------------------------

EXTRA_HELP = [[

Usage:

  ]] .. arg[0] .. [[ --root=<PROJECT_PATH> <action> [options]

Actions:

  * ]] .. table.concat(tkeys(ACTIONS), "\n  * ") .. [[

]]

--------------------------------------------------------------------------------

local run = function(...)
  CONFIG, ARGS = assert(load_tools_cli_config(
      function(args)
        local action = args[1] or args["--action"]
        local param = { }

        if
          tset({
              "update_changes";
              "update_tables";
              "update_tables_test_data";
              "update_db";
              "update_data_changeset"
            })[action]
        then
          param.force = not not args["force"]
        end

        if action == "update_data_changeset" then
          param.table_name = args[2] or args["--table-name"]
        end

        if action == "initialize_db" then
          param.db_name = args[2] or args["--db-name"]
          param.force = not not args["force"]
        elseif action == "revert_changes" then
          param.stop_at_uuid = args[2] or args["--uuid"]
          if args["--revert-all"] then
            param.stop_at_uuid = "all" -- Hack.
          end
        end

        return
        {
          PROJECT_PATH = assert(args["--root"], "missing --root");
          dbgen =
          {
            action =
            {
              name = action;
              param = param;
            };
          }
        }
      end,
      EXTRA_HELP,
      SCHEMA,
      nil,
      nil,
      ...
    ))

  ACTIONS[CONFIG.dbgen.action.name]()
end

--------------------------------------------------------------------------------

return
{
  run = run;
}
