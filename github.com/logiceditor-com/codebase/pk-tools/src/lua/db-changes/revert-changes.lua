--------------------------------------------------------------------------------
-- revert-changes.lua: db changeset revert tool
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

local is_string
      = import 'lua-nucleo/type.lua'
      {
        'is_string'
      }

local timapofrecords
      = import 'lua-nucleo/table-utils.lua'
      {
        'timapofrecords'
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
      revert_db_changeset,
      is_changeset_installed,
      load_all_changesets
      = import 'pk-engine/db/changeset.lua'
      {
        'does_changeset_table_exist',
        'revert_db_changeset',
        'is_changeset_installed',
        'load_all_changesets'
      }

local make_loggers
      = import 'pk-core/log.lua'
      {
        'make_loggers'
      }

--------------------------------------------------------------------------------

local log, dbg, spam, log_error = make_loggers("revert-changes", "RCH")

--------------------------------------------------------------------------------

-- TODO: Generalize copy-paste with upload-changes!
local revert_changes = function(
    db_changes_path,
    config_host,
    config_port,
    stop_at_uuid
  )
  arguments(
      "string", db_changes_path,
      "string", config_host,
      "number", config_port
    )

  local changesets = assert(load_all_changesets(db_changes_path))
  local changesets_by_uuid = timapofrecords(changesets, "UUID")

  local db_has_changeset_table = { }

  local config_manager = assert(make_config_manager(config_host, config_port))
  local db_manager = assert(
      make_db_manager(
          config_manager,
          make_db_connection_manager()
        )
    )

  if not is_string(stop_at_uuid) then
    assert(stop_at_uuid == false or stop_at_uuid == nil)
    stop_at_uuid = false -- For consistency
  else
    local changeset = assert(
        changesets_by_uuid[stop_at_uuid],
        "unknown stop uuid"
      )

    local db_name = assert(changeset.DB_NAME, "missing changeset.DB_NAME")
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

    assert(
        is_changeset_installed(db_conn, changeset),
        "stop uuid is not installed"
      )
  end

  for i = #changesets, 1, -1 do
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
          "---> skipping not installed changeset `", changeset.UUID, "'\n"
        )
      io.stdout:flush()
    else
      io.stdout:write("---> reverting changeset `", changeset.UUID, "'\n")
      io.stdout:flush()

      assert(revert_db_changeset(db_conn, changeset))
      io.stdout:write(
          "---> successfully reverted changeset `", changeset.UUID, "'\n"
        )
      io.stdout:flush()
    end

    if changeset.UUID == stop_at_uuid then
      io.stdout:write("---> stopping at `", changeset.UUID, "' as requested\n")
      io.stdout:flush()
      break
    end
  end

  io.stdout:write("---> done reverting changesets\n")
  io.stdout:flush()
end

--------------------------------------------------------------------------------

return
{
  revert_changes = revert_changes;
}
