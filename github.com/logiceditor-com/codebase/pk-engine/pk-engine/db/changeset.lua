--------------------------------------------------------------------------------
-- changeset.lua: applying and reverting db changesets
-- This file is a part of pk-engine library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------

local tostring, pcall, xpcall = tostring, pcall, xpcall
local os_time = os.time
local table_sort = table.sort

--------------------------------------------------------------------------------

local arguments,
      method_arguments,
      optional_arguments
      = import 'lua-nucleo/args.lua'
      {
        'arguments',
        'method_arguments',
        'optional_arguments'
      }

local is_string
      = import 'lua-nucleo/type.lua'
      {
        'is_string'
      }

local assert_is_string
      = import 'lua-nucleo/typeassert.lua'
      {
        'assert_is_string'
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

--------------------------------------------------------------------------------

local log, dbg, spam, log_error = make_loggers("db/changeset", "DCH")

--------------------------------------------------------------------------------

-- TODO: Make these constants configurable
local MAX_UUID_LENGTH = 128
local CHANGESET_TABLE_NAME = "pk_changes"

--------------------------------------------------------------------------------

local create_changeset_table = function(db_conn)
  arguments(
      "userdata", db_conn
    )

  local res, err = db_conn:execute([[
      CREATE TABLE `]]..CHANGESET_TABLE_NAME..[[` (
          `id` int(11) NOT NULL auto_increment,
          `uuid` varchar(]]..MAX_UUID_LENGTH..[[) NOT NULL default '',
          `stime` int(11) NOT NULL default '0',
          PRIMARY KEY (`id`),
          UNIQUE KEY `uuid` (`uuid`),
          KEY `stime` (`stime`),
          KEY `uuid-stime` (`uuid`, `stime`)
        ) ENGINE=MyISAM DEFAULT CHARSET=utf8;
    ]])

  if not res then
    local msg = "failed to create changeset table: " .. err
    log_error("create_changeset_table:", msg)
    return nil, msg
  end

  return true
end

local drop_changeset_table = function(db_conn)
  arguments(
      "userdata", db_conn
    )

  local res, err = db_conn:execute([[DROP TABLE `]]..CHANGESET_TABLE_NAME..[[`]])
  if not res then
    local msg = "failed to drop changeset table: " .. err
    log_error("drop_changeset_table:", msg)
    return nil, msg
  end

  return true
end

local does_changeset_table_exist = function(db_conn)
  arguments(
      "userdata", db_conn
    )

  local cursor, err = db_conn:execute([[SHOW TABLES LIKE "]]..CHANGESET_TABLE_NAME..[["]])
  if not cursor then
    local msg = "failed to check changeset table existance: " .. err
    log_error("does_changeset_table_exist:", msg)
    return nil, msg
  end

  local res = cursor:fetch()
  if res == CHANGESET_TABLE_NAME then
    res = true
  else
    res = false
  end

  cursor:close()

  return res
end

--------------------------------------------------------------------------------

local apply_db_changeset = function(db_conn, changeset)
  arguments(
      "userdata", db_conn,
      "table", changeset
    )

  -- Writing to changeset list ahead of apply to ensure UUID is unique.
  -- TODO: Use some generic function.
  local time = os_time()
  local res, err = db_conn:execute(
          [[INSERT INTO `]]..CHANGESET_TABLE_NAME..[[`]]
       .. [[ (`uuid`, `stime`)]]
       .. [[ VALUES(']]
       .. db_conn:escape(assert_is_string(changeset.UUID))
       .. [[', ']] .. time .. [[')]]
     )
  if res ~= 1 then
    if not res then
      local msg = "failed to register changeset: " .. tostring(err)
      log_error("apply_db_changeset:", msg)
      return nil, msg
    else
      local msg = "register changeset: unexpected number of affected rows: "..tostring(res)
      log_error("apply_db_changeset:", msg)
      return nil, msg
    end
  end

  local status, res, err = xpcall(
      function() return changeset.apply(db_conn) end,
      function(msg)
        log_error(debug.traceback(msg))
        return msg
      end
    )
  if not status or not res then
    -- TODO: Use some generic function.
    local undo_res, undo_err = db_conn:execute(
        [[DELETE FROM `]]..CHANGESET_TABLE_NAME..[[`]]
     .. [[ WHERE 1]]
     .. [[ AND `uuid`=']]..db_conn:escape(assert_is_string(changeset.UUID))..[[']]
     .. [[ AND `stime`=']]..time..[[']]
      )
    if undo_res ~= 1 then
      if not undo_res then
        local msg = "failed to undo changeset registration after error " .. undo_err
            .. " original error was: " .. err
        log_error("apply_db_changeset:", msg)
        return nil, msg
      else
        local msg = "undo changeset registration after error:"
          .. " unexpected number of affected rows " .. tostring(undo_res)
          .. " original error was: " .. err
        log_error("apply_db_changeset:", msg)
        return nil, msg
      end
    end

    err = (not status) and res or err
    return nil, "failed to apply changeset `" .. changeset.UUID .. "': " .. err
  end

  return true
end

local list_installed_changesets = function(db_conn)
  arguments(
      "userdata", db_conn
    )

  local cursor, err = db_conn:execute(
      [[SELECT `uuid`, `stime` FROM `]]..CHANGESET_TABLE_NAME..[[`]]
   .. [[ WHERE 1 ORDER BY `id` DESC]]
    )
  if not cursor then
    local msg = "failed to list installed changesets: " .. err
    log_error("list_installed_changesets:", msg)
    return nil, msg
  end

  local result = { }
  local uuid, stime = cursor:fetch()
  while uuid do
    result[#result + 1] =
    {
      UUID = assert_is_string(uuid);
      stime = assert_is_string(stime);
    }

    uuid, stime = cursor:fetch()
  end

  cursor:close()

  return result
end

-- Returns false if changeset list is empty
local get_top_db_changeset_uuid = function(db_conn)
  arguments(
      "userdata", db_conn
    )

  -- TODO: Use some generic function.
  local cursor, err = db_conn:execute(
      [[SELECT `uuid`, `stime` FROM `]]..CHANGESET_TABLE_NAME..[[`]]
   .. [[ WHERE 1 ORDER BY `id` DESC LIMIT 1]]
    )
  if not cursor then
    local msg = "failed to select last changeset: " .. err
    log_error("get_top_db_changeset_uuid:", msg)
    return nil, msg
  end

  local uuid, stime = cursor:fetch()
  cursor:close()

  if not uuid then
    --spam("get_top_db_changeset_uuid: found no registered changesets (probably OK)")
    return false
  end

  return
    assert_is_string(uuid),
    assert_is_string(stime)
end

local is_changeset_installed = function(db_conn, changeset)
  arguments(
      "userdata", db_conn,
      "table", changeset
    )

  -- TODO: Use some generic function.
  local cursor, err = db_conn:execute(
      [[SELECT COUNT(*) FROM `]]..CHANGESET_TABLE_NAME..[[`]]
   .. [[ WHERE 1]]
   .. [[ AND `uuid`=']]..db_conn:escape(assert_is_string(changeset.UUID))..[[']]
    )
  if not cursor then
    local msg = "failed to count changesets: " .. err
    log_error("apply_db_changeset:", msg)
    return nil, msg
  end

  local count = cursor:fetch()
  cursor:close()

  if count ~= "1" then
    if count ~= "0" then
      local msg = "unexpected changeset install count, got " .. tostring(count)
        .. ", expected 1 or 0"
      log_error("apply_db_changeset:", msg)
      return nil, msg
    else
      return false -- Not installed
    end
  end

  return true
end

local revert_db_changeset = function(db_conn, changeset)
  arguments(
      "userdata", db_conn,
      "table", changeset
    )

  -- TODO: NOT ATOMIC enough! Must use join (or lock table)!

  local actual_uuid, stime = get_top_db_changeset_uuid(db_conn)
  if actual_uuid == false then
    local msg = "can't revert changeset, changeset list is empty"
    log_error("revert_db_changeset", changeset.UUID, ":", msg)
    return nil, msg
  elseif actual_uuid == nil then
    local err = stime
    log_error("revert_db_changeset", changeset.UUID, ":", err)
    return nil, "can't revert changeset: " .. err
  end

  if changeset.UUID ~= actual_uuid then
    local msg = "top-level uuid mismatch, expected `"..changeset.UUID
        .. "', got `"..actual_uuid.."'"

    log_error("revert_db_changeset", changeset.UUID, ":", msg)

    return nil, msg
  end

  local res, err = changeset.revert(db_conn)
  if not res then
    log_error("revert_db_changeset", changeset.UUID, ":", err)

    return nil, "failed to revert changeset: " .. tostring(err)
  end

  -- NOTE: If this fails, DB is in inconsistent state
  --       and we can't do much about it.
  local res, err = db_conn:execute(
      [[DELETE FROM `]]..CHANGESET_TABLE_NAME..[[`]]
   .. [[ WHERE 1]]
   .. [[ AND `uuid`=']]..db_conn:escape(changeset.UUID)..[[']]
   .. [[ AND `stime`=']]..stime..[[']]
   .. [[ LIMIT 1]]
    )
  if res ~= 1 then
    local msg
    if not res then
      msg = "failed to unregister changeset: " .. err
    else
      msg = "failed to unregister changeset: unexpected number of affected rows: " .. tostring(res)
    end
    log_error("revert_db_changeset", changeset.UUID, ":", msg)
    return nil, msg
  end

  return true
end

--------------------------------------------------------------------------------

local load_all_changesets = function(db_changes_path)
  arguments(
      "string", db_changes_path
    )

  local filenames = find_all_files(
      db_changes_path,
      ".*%.lua$",
      { }
    )

  table_sort(filenames)

  spam("found db changeset files", filenames)
  if #filenames == 0 then
    return nil, "no changeset files found"
  end

  -- TODO: Need to figure out which db to put this data in.

  -- TODO: Validate more?
  local uuids = { }
  local changesets = { }
  for i = 1, #filenames do
    local filename = filenames[i]

    local changeset = assert(assert(loadfile(filename)) ())

    -- spam("loaded changeset", filename, changeset)

    local DB_NAME = changeset.DB_NAME

    if not is_string(DB_NAME) then
      return nil, "bad DB_NAME type in file " .. filename
    end

    local UUID = changeset.UUID

    if not is_string(UUID) then
      return nil, "bad UUID type in file " .. filename
    end

    if uuids[UUID] ~= nil then
      return nil, "duplicate UUID found in file " .. filename
    end

    if UUID == "" then
      return nil, "empty UUID in file " .. filename
    end

    if #UUID > MAX_UUID_LENGTH then
      return nil, "uuid too long in file " .. filename
    end

    uuids[UUID] = true

    changesets[#changesets + 1] = changeset
  end

  return changesets
end

--------------------------------------------------------------------------------

return
{
  create_changeset_table = create_changeset_table;
  drop_changeset_table = drop_changeset_table;
  does_changeset_table_exist = does_changeset_table_exist;
  --
  apply_db_changeset = apply_db_changeset;
  get_top_db_changeset_uuid = get_top_db_changeset_uuid;
  is_changeset_installed = is_changeset_installed;
  revert_db_changeset = revert_db_changeset;
  list_installed_changesets = list_installed_changesets;
  --
  load_all_changesets = load_all_changesets;
}
