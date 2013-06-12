--------------------------------------------------------------------------------
-- run.lua: the resource updater
-- This file is a part of pk-tools library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------

local lfs = require 'lfs'

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
      tstr,
      tkeys,
      timapofrecords
      = import 'lua-nucleo/table.lua'
      {
        'empty_table',
        'timap',
        'tstr',
        'tkeys',
        'timapofrecords'
      }

local make_loggers
      = import 'pk-core/log.lua'
      {
        'make_loggers'
      }

local find_all_files
      = import 'lua-aplicado/filesystem.lua'
      {
        'find_all_files'
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

local make_enquirer
      = import 'pk-engine/db/enquirer.lua'
      {
        'make_enquirer'
      }

local postquery_for_data
      = import 'pk-engine/db/query.lua'
      {
        'postquery_for_data'
      }

local TABLES = import 'logic/db/tables.lua' ()

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
      = import 'apigen/project-config/schema.lua'
      {
        'create_config_schema',
      }

--------------------------------------------------------------------------------

local log, dbg, spam, log_error = make_loggers("resources/main", "REM")

--------------------------------------------------------------------------------

-- NOTE: Generation requires fixed random seed for consistency
math.randomseed(12345)

--------------------------------------------------------------------------------

-- TODO: Support unity resources better!

local find_resource_files = function(resources_dir, path_prefix)
  local files = { }

  do
    local filenames = find_all_files(resources_dir, ".*")
    table.sort(filenames) -- For consistency

    for i = 1, #filenames do
      local filename = filenames[i]

      -- TODO: find_all_files() already asked for file attributes. Reuse.
      local attributes = assert(lfs.attributes(filename))

      files[#files + 1] = -- Imitating a resource db record
      {
        path_flash = path_prefix .. filename:sub(#resources_dir + 1);

        -- TODO: WTF?! Support unity resources properly
        path_unity = (
            path_prefix .. filename:sub(#resources_dir + 1)
          ):gsub("/flash/", "/unity/"):gsub("%..+$", ".unity3d");

        size = tostring(attributes.size);
        mtime = tostring(attributes.modification);
      }
    end
  end

  return files
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

ACTIONS.list = function()
  local config_host = CONFIG.common.internal_config.production.host
  local config_port = CONFIG.common.internal_config.production.port
  local resources_dir = CONFIG.common.resources.dir
  local path_prefix = CONFIG.common.resources.path_prefix

  local config_manager = assert(make_config_manager(config_host, config_port))
  local db_manager = assert(
      make_db_manager(
          config_manager,
          make_db_connection_manager()
        )
    )
  local db_conn, conn_id = assert(
      db_manager:acquire_db_connection(
          TABLES.resources.db_name
        )
    )
  local enquirer = make_enquirer(
      TABLES.resources.table,
      TABLES.resources.primary_key
    )

  -- Find all files
  local actual_files = find_resource_files(resources_dir, path_prefix)

  -- List all resources in DB
  local registered_files = assert(
      enquirer:list(db_conn, " ORDER BY `path_flash`")
    )
  local registered_files_by_path = timapofrecords(
      registered_files,
      "path_flash"
    )

  local have_new_files = false
  local have_changed_files = false
  local have_deleted_files = false

  for i = 1, #actual_files do
    local actual = actual_files[i]

    local status = "[       ]"
    local registered = registered_files_by_path[actual.path_flash]
    if not registered then
      status = "[NEW    ]"
      have_new_files = true
    elseif
      registered.size ~= actual.size or
      registered.mtime ~= actual.mtime
    then
      status = "[CHANGED]"
      have_changed_files = true
    end

    registered_files_by_path[actual.path_flash] = nil

    io.stdout:write(
        "--->",
        " ", (registered and ("(%6d)"):format(registered.id) or "(     +)"),
        " ", status,
        " ", actual.path_flash,
        "\n"
      )
  end

  for path, info in pairs(registered_files_by_path) do
    io.stdout:write(
        "--->",
        " ", ("(%6d)"):format(info.id),
        " ", "[DELETED]",
        " ", path,
        "\n"
      )
    have_deleted_files = true
  end

  if have_new_files or have_changed_files then
    io.stdout:write("\n")
    io.stdout:write(
        "---> WARNING: Changed and / or new files detected. Run update.\n"
      )
  end

  if have_deleted_files then
    io.stdout:write("\n")
    io.stdout:write("---> WARNING: Deleted files detected. Run purge.\n")
  end

  io.stdout:write("\n")
  io.stdout:write("OK\n")
  io.stdout:flush()
end

ACTIONS.update = function()
  local config_host = CONFIG.common.internal_config.production.host
  local config_port = CONFIG.common.internal_config.production.port
  local resources_dir = CONFIG.common.resources.dir
  local path_prefix = CONFIG.common.resources.path_prefix

  local config_manager = assert(make_config_manager(config_host, config_port))
  local db_manager = assert(
      make_db_manager(
          config_manager,
          make_db_connection_manager()
        )
    )
  local db_conn, conn_id = assert(
      db_manager:acquire_db_connection(
          TABLES.resources.db_name
        )
    )
  local enquirer = make_enquirer(
      TABLES.resources.table,
      TABLES.resources.primary_key
    )

  -- Find all files
  local actual_files = find_resource_files(resources_dir, path_prefix)
  local actual_files_by_path = timapofrecords(actual_files, "path_flash")

  -- List all resources in DB
  local registered_files = assert(
      enquirer:list(db_conn, " ORDER BY `path_flash`")
    )

  for i = 1, #registered_files do
    local registered = registered_files[i]

    local actual = actual_files_by_path[registered.path_flash]
    if not actual then
      io.stdout:write(
          "---> WARNING: skipping DELETED file `",
          registered.path_flash, "'.\n",
          "--->          Run purge to remove\n"
        )
    elseif
      registered.size ~= actual.size or
      registered.mtime ~= actual.mtime
    then
      io.stdout:write(
          "---> updating resource info for `", registered.path_flash, "'.\n"
        )
      registered.size = actual.size
      registered.mtime = actual.mtime

      assert(enquirer:update_one(db_conn, registered))
    else
      io.stdout:write(
          "---> skipping unmodified resource `", registered.path_flash, "'.\n"
        )
    end

    actual_files_by_path[registered.path_flash] = nil
  end

  -- Preserving order
  -- TODO: Do not iterate *all* resources again.
  for i = 1, #actual_files do
    local path = actual_files[i].path_flash
    local actual = actual_files_by_path[path]
    if actual then
      io.stdout:write(
          "---> adding resource info for `", path, "'.\n"
        )
      assert(enquirer:insert_one(db_conn, actual))
    end
  end

  io.stdout:write("\n")
  io.stdout:write("OK\n")
  io.stdout:flush()
end

ACTIONS.purge = function()
  local config_host = CONFIG.common.internal_config.production.host
  local config_port = CONFIG.common.internal_config.production.port
  local resources_dir = CONFIG.common.resources.dir
  local path_prefix = CONFIG.common.resources.path_prefix

  local config_manager = assert(make_config_manager(config_host, config_port))
  local db_manager = assert(
      make_db_manager(
          config_manager,
          make_db_connection_manager()
        )
    )
  local db_conn, conn_id = assert(
      db_manager:acquire_db_connection(
          TABLES.resources.db_name
        )
    )
  local enquirer = make_enquirer(
      TABLES.resources.table,
      TABLES.resources.primary_key
    )

  -- Find all files
  local actual_files = find_resource_files(resources_dir, path_prefix)
  local actual_files_by_path = timapofrecords(actual_files, "path_flash")

  -- List all resources in DB
  local registered_files = assert(
      enquirer:list(db_conn, " ORDER BY `path_flash`")
    )

  for i = 1, #registered_files do
    local registered = registered_files[i]

    local actual = actual_files_by_path[registered.path_flash]
    if not actual then
      io.stdout:write(
          "---> DELETING ", tstr(registered), "\n"
        )

      assert(
          assert(
              enquirer:delete_many(
                  db_conn, 1, postquery_for_data(db_conn, registered)
                )
            ) == 1
        )
    else
      io.stdout:write(
          "---> skipping existing resource `", registered.path_flash, "'.\n"
        )
    end

    actual_files_by_path[registered.path_flash] = nil
  end

  io.stdout:write("\n")
  io.stdout:write("OK\n")
  io.stdout:flush()
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
          resources = { action = { name = args[1] or args["--action"]; }; };
        }
      end,
      EXTRA_HELP,
      SCHEMA,
      nil,
      nil,
      ...
    ))

  ACTIONS[CONFIG.resources.action.name]()
end

--------------------------------------------------------------------------------

return
{
  run = run;
}
