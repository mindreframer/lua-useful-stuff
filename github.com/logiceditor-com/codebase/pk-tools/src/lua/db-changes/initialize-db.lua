--------------------------------------------------------------------------------
-- initialize-db.lua: db ininialization tool
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

local tstr
      = import 'lua-nucleo/tstr.lua'
      {
        'tstr'
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

local does_changeset_table_exist,
      create_changeset_table
      = import 'pk-engine/db/changeset.lua'
      {
        'does_changeset_table_exist',
        'create_changeset_table'
      }

local list_db_tables
      = import 'pk-engine/db/info.lua'
      {
        'list_db_tables'
      }

local make_loggers
      = import 'pk-core/log.lua'
      {
        'make_loggers'
      }

--------------------------------------------------------------------------------

local log, dbg, spam, log_error = make_loggers("initialize-db", "IDB")

--------------------------------------------------------------------------------

local initialize_db = function(db_changes_path, config_host, config_port, db_name, force)
  arguments(
      "string", db_changes_path, -- unused, listed for API consistency
      "string", config_host,
      "number", config_port,
      "string", db_name,
      "boolean", force
    )

  local config_manager = assert(make_config_manager(config_host, config_port))
  local db_manager = assert(make_db_manager(config_manager, make_db_connection_manager()))

  local db_conn, conn_id = assert(db_manager:acquire_db_connection(db_name))

  local res, err = does_changeset_table_exist(db_conn)
  if res == nil then
    error(err)
  elseif res == true then
    error("changeset table already exists in db `" .. db_name .. "'")
  end

  local db_tables = assert(list_db_tables(db_conn))
  if next(db_tables) ~= nil then
    if not force then
      error(
          "db `" .. db_name .. "' is not empty,"
       .. " refusing to continue without force flag\n"
       .. " found tables: " .. tstr(db_tables)
        )
    end

    io.stdout:write(
        "---> WARNING: found some tables in `", db_name, "':\n",
        "--->          ", tstr(db_tables), "\n",
        "--->          Continuing due to force flag. May the force be with you!\n"
      )
    io.stdout:flush()
  end

  assert(create_changeset_table(db_conn))

  db_manager:unacquire_db_connection(db_conn, conn_id)

  io.stdout:write(
      "---> changeset table successfully created in db `", db_name, "'\n",
      "---> done\n"
    )
  io.stdout:flush()
end

--------------------------------------------------------------------------------

return
{
  initialize_db = initialize_db;
}
