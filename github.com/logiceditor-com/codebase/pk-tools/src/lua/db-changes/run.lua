--------------------------------------------------------------------------------
-- run.lua: db-changes runner
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

local initialize_db
      = import 'db-changes/initialize-db.lua'
      {
        'initialize_db'
      }

local list_changes
      = import 'db-changes/list-changes.lua'
      {
        'list_changes'
      }

local upload_changes
      = import 'db-changes/upload-changes.lua'
      {
        'upload_changes'
      }

local revert_changes
      = import 'db-changes/revert-changes.lua'
      {
        'revert_changes'
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
      = import 'db-changes/project-config/schema.lua'
      {
        'create_config_schema',
      }

--------------------------------------------------------------------------------

local log, dbg, spam, log_error = make_loggers("db-changes/run", "DCR")

--------------------------------------------------------------------------------

local SCHEMA, EXTRA_HELP, CONFIG, ARGS

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

ACTIONS.initialize_db = function()
  local config_host = CONFIG.common.internal_config.deploy.host
  local config_port = CONFIG.common.internal_config.deploy.port

  local db_name = CONFIG.db_changes.action.param.db_name
  local force = CONFIG.db_changes.action.param.force
  local changes_dir = CONFIG.common.db.changes_dir

  initialize_db(changes_dir, config_host, config_port, db_name, force)
end

ACTIONS.list_changes = function()
  local config_host = CONFIG.common.internal_config.deploy.host
  local config_port = CONFIG.common.internal_config.deploy.port

  local changes_dir = CONFIG.common.db.changes_dir

  list_changes(changes_dir, config_host, config_port)
end

ACTIONS.upload_changes = function()
  local config_host = CONFIG.common.internal_config.deploy.host
  local config_port = CONFIG.common.internal_config.deploy.port

  local changes_dir = CONFIG.common.db.changes_dir

  upload_changes(changes_dir, config_host, config_port)
end

ACTIONS.revert_changes = function()
  local config_host = CONFIG.common.internal_config.deploy.host
  local config_port = CONFIG.common.internal_config.deploy.port

  local stop_at_uuid = CONFIG.db_changes.action.param.stop_at_uuid
  local changes_dir = CONFIG.common.db.changes_dir

  if stop_at_uuid == "all" then
    log("reverting all changesets")
    stop_at_uuid = false
  end

  revert_changes(changes_dir, config_host, config_port, stop_at_uuid)
end

--------------------------------------------------------------------------------

EXTRA_HELP = [[

Usage:

  db-changes --root=<PROJECT_PATH> <action> [options]

Actions:

  * ]] .. table.concat(tkeys(ACTIONS), "\n  * ") .. [[

]]

--------------------------------------------------------------------------------

local run = function(...)
  SCHEMA = create_config_schema()

  CONFIG, ARGS = assert(load_tools_cli_config(
      function(args)
        -- TODO: Must include all those into help

        local action = args[1] or args["--action"]
        local param = { }

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
          PROJECT_PATH = args["--root"];
          db_changes =
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

  ACTIONS[CONFIG.db_changes.action.name]()
end

--------------------------------------------------------------------------------

return
{
  run = run;
}
