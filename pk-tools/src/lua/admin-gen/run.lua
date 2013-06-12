--------------------------------------------------------------------------------
-- run.lua: server handlers and client code generator
-- This file is a part of pk-tools library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
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
      tkeys
      = import 'lua-nucleo/table.lua'
      {
        'empty_table',
        'timap',
        'tkeys'
      }

local make_loggers
      = import 'pk-core/log.lua'
      {
        'make_loggers'
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

local generate_client_api_schema
      = import 'admin-gen/generate-client-api-schema.lua'
      {
        'generate_client_api_schema'
      }

local generate_js
      = import 'admin-gen/generate-js.lua'
      {
        'generate_js'
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
      = import 'admin-gen/project-config/schema.lua'
      {
        'create_config_schema',
      }

--------------------------------------------------------------------------------

local log, dbg, spam, log_error = make_loggers("admin-gen", "ADG")

--------------------------------------------------------------------------------

-- NOTE: Generation requires fixed random seed for consistency
math.randomseed(12345)

--------------------------------------------------------------------------------

local EXTRA_HELP, CONFIG, ARGS

--------------------------------------------------------------------------------

local SCHEMA = create_config_schema()

local ACTIONS = { }

ACTIONS.help = function()
  print_tools_cli_config_usage(EXTRA_HELP, SCHEMA)
end

ACTIONS.generate_admin_api_schema = function()
  local tables = load_db_schema(CONFIG.admin_gen.db_schema_filename)
  validate_db_schema(tables)

  local template_dir = CONFIG.admin_gen.template_api_dir
  local out_dir = CONFIG.admin_gen.intermediate.api_schema_dir

  -- TODO: Detect obsolete files and fail instead of this!
  log("Removing", out_dir)
  assert(
      os.execute( -- TODO: Use lfs.
          'rm -rf "' .. out_dir .. '"'
        ) == 0
    )

  log("Generating client api schema to", out_dir)
  generate_client_api_schema(tables, template_dir, out_dir)

  log("OK")
end

ACTIONS.check_config = function()
  io.stdout:write("config OK\n")
  io.stdout:flush()
end

ACTIONS.dump_config = function()
  io.stdout:write(tpretty(freeform_table_value(CONFIG), " ", 80), "\n")
  io.stdout:flush()
end

ACTIONS.generate_js = function(
    db_schema_filename
  )
  local ACTION_CONFIG = CONFIG.admin_gen.action.param.generate_js
  local must_generate_navigator = ACTION_CONFIG.must_generate_navigator

  local tables = load_db_schema(CONFIG.admin_gen.db_schema_filename)
  validate_db_schema(tables)

  local template_dir = CONFIG.admin_gen.template_js_dir
  local out_dir = CONFIG.admin_gen.intermediate.js_dir

  -- TODO: Detect obsolete files and fail instead of this!
  log("Removing", out_dir)
  assert(
      os.execute( -- TODO: Use lfs.
          'rm -rf "' .. out_dir .. '"'
        ) == 0
    )

  log("Generating js to", out_dir)
  generate_js(tables, template_dir, out_dir, must_generate_navigator)

  log("OK")
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
        return
        {
          PROJECT_PATH = args["--root"];
          admin_gen = { action = { name = args[1] or args["--action"]; }; };
        }
      end,
      EXTRA_HELP,
      SCHEMA,
      nil,
      nil,
      ...
    ))

  ACTIONS[CONFIG.admin_gen.action.name]()
end

--------------------------------------------------------------------------------

return
{
  run = run;
}
