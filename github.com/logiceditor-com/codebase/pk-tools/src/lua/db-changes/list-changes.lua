--------------------------------------------------------------------------------
-- list-changes.lua: db changeset info tool
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
      load_all_changesets,
      list_installed_changesets
      = import 'pk-engine/db/changeset.lua'
      {
        'does_changeset_table_exist',
        'apply_db_changeset',
        'is_changeset_installed',
        'load_all_changesets',
        'list_installed_changesets'
      }

local make_loggers
      = import 'pk-core/log.lua'
      {
        'make_loggers'
      }

--------------------------------------------------------------------------------

local log, dbg, spam, log_error = make_loggers("list-changes", "LCH")

--------------------------------------------------------------------------------

-- TODO: Generalize copy-paste with upload_changes!
local list_changes = function(db_changes_path, config_host, config_port)
  arguments(
      "string", db_changes_path,
      "string", config_host,
      "number", config_port
    )

  local config_manager = assert(make_config_manager(config_host, config_port))
  local db_manager = assert(
      make_db_manager(
          config_manager,
          make_db_connection_manager()
        )
    )
  local not_installed_changesets = { }
  local known_installed_uuids = { }
  local actual_installed_changesets_by_db = { }

  local broken_sequence_detected = false
  do
    local changesets = assert(load_all_changesets(db_changes_path))
    local db_has_changeset_table = { }
    local db_has_uninstalled_changesets = { }

    for i = 1, #changesets do
      local changeset = changesets[i]

      local db_name = assert(changeset.DB_NAME, "missing changeset.DB_NAME")

      -- TODO: DB handling should be done in some lower-level function.
      --       Here is_changeset_installed(db_manager, changeset)
      --       should be called.
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

      if not actual_installed_changesets_by_db[db_name] then
        actual_installed_changesets_by_db[db_name] = assert(
            list_installed_changesets(db_conn)
          )
      end

      local is_installed, err = is_changeset_installed(db_conn, changeset)
      if is_installed == nil then
        error(err)
      end

      if not is_installed then
        io.stdout:write(
            "---> changeset `", changeset.UUID,
            "' for db `", db_name, "` NOT INSTALLED\n"
          )
        io.stdout:flush()

        not_installed_changesets[#not_installed_changesets + 1] = changeset
        db_has_uninstalled_changesets[db_name] = true
      else
        if db_has_uninstalled_changesets[db_name] then
          io.stdout:write(
              "---> FATAL broken changeset sequence: have not-installed",
              " changesets before installed one (installed UUID `", changeset.UUID, "', db `", db_name, "')\n"
           )
          broken_sequence_detected = true
        end

        known_installed_uuids[changeset.UUID] = true

        io.stdout:write(
            "---> changeset `", changeset.UUID,
            "' in db `", db_name, "` installed\n"
          )
      end

      db_manager:unacquire_db_connection(db_conn, conn_id)
    end
  end

  local have_unknown_changesets = false
  for db_name, actual_changesets in pairs(actual_installed_changesets_by_db) do
    for i = 1, #actual_changesets do
      local UUID = actual_changesets[i].UUID
      if not known_installed_uuids[UUID] then
        have_unknown_changesets = true

        -- This most likely means that changeset files
        -- were forcefully regenerated.
        io.stdout:write(
            "---> changeset `", UUID,
            "' in db `", db_name, "` UNKNOWN but instaled\n"
          )
      end
    end
  end

  local err = ""
  if broken_sequence_detected then
    err = err .. "changeset sequence is broken\n"
  end
  if have_unknown_changesets then
    err = err .. "unknown installed changesets detected\n"
  end

  if err ~= "" then
    io.stdout:write("\n")
    io.stdout:flush()
    error("FATAL ERROR\n" .. err)
  end

  if #not_installed_changesets == 0 then
    io.stdout:write("---> no new changesets found\n")
    io.stdout:flush()
  end

  io.stdout:write("---> done\n")
  io.stdout:flush()
end

--------------------------------------------------------------------------------

return
{
  list_changes = list_changes;
}
