--------------------------------------------------------------------------------
-- upload-changes.lua: db changeset upload tool
-- This file is a part of pk-tools library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
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
      apply_db_changeset,
      is_changeset_installed,
      load_all_changesets
      = import 'pk-engine/db/changeset.lua'
      {
        'does_changeset_table_exist',
        'apply_db_changeset',
        'is_changeset_installed',
        'load_all_changesets'
      }

local make_loggers
      = import 'pk-core/log.lua'
      {
        'make_loggers'
      }

--------------------------------------------------------------------------------

local log, dbg, spam, log_error = make_loggers("upload-changes", "UCH")

--------------------------------------------------------------------------------

local upload_changes = function(db_changes_path, config_host, config_port)
  arguments(
      "string", db_changes_path,
      "string", config_host,
      "number", config_port
    )

  local config_manager = assert(make_config_manager(config_host, config_port))
  local db_manager = assert(make_db_manager(config_manager, make_db_connection_manager()))
  local not_installed_changesets = { }

  --
  -- Pass one: filter out installed changesets and check for errors
  --

  do
    local changesets = assert(load_all_changesets(db_changes_path))
    local db_has_changeset_table = { }
    local db_has_uninstalled_changesets = { }

    for i = 1, #changesets do
      local changeset = changesets[i]

      local db_name = assert(changeset.DB_NAME, "missing changeset.DB_NAME")

      -- TODO: DB handling should be done in some lower-level function.
      --       Here is_changeset_installed(db_manager, changeset) should be called.
      local db_conn, conn_id = assert(db_manager:acquire_db_connection(db_name))

      if not db_has_changeset_table[db_name] then
        local res, err = does_changeset_table_exist(db_conn)
        if res == nil then
          error(err)
        elseif res then
          db_has_changeset_table[db_name] = true
        else
          error("db `" .. db_name .. "' has no changeset table")
        end
      end

      local is_installed, err = is_changeset_installed(db_conn, changeset)
      if is_installed == nil then
        error(err)
      end

      if not is_installed then
        io.stdout:write(
            "---> found not installed changeset `", changeset.UUID,
            "' for db `", db_name, "`\n"
          )
        io.stdout:flush()

        not_installed_changesets[#not_installed_changesets + 1] = changeset
        db_has_uninstalled_changesets[db_name] = true
      else
        if db_has_uninstalled_changesets[db_name] then
          error(
              "broken changeset sequence: have not-installed changesets"
           .. " before installed one (installed UUID `" .. changeset.UUID
           .. "', db `" .. db_name .. "')"
            )
        end

        io.stdout:write(
            "---> skipping installed changeset `", changeset.UUID,
            "' in db `", db_name, "`\n"
          )
      end

      db_manager:unacquire_db_connection(db_conn, conn_id)
    end
  end

  --
  -- Pass two: apply changesets
  --

  if #not_installed_changesets == 0 then
    io.stdout:write("---> no new changesets found\n")
    io.stdout:flush()
    return os.exit(0)
  end

  for i = 1, #not_installed_changesets do
    local changeset = not_installed_changesets[i]

    local db_name = assert(changeset.DB_NAME, "missing changeset.DB_NAME")

    local db_conn, conn_id = assert(db_manager:acquire_db_connection(db_name))

    io.stdout:write("---> applying changeset `", changeset.UUID, "' to db: `", db_name, "' \n")
    io.stdout:flush()

    assert(apply_db_changeset(db_conn, changeset))

    db_manager:unacquire_db_connection(db_conn, conn_id)
  end

  io.stdout:write("---> done\n")
  io.stdout:flush()
end

--------------------------------------------------------------------------------

return
{
  upload_changes = upload_changes;
}
