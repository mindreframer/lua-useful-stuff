--------------------------------------------------------------------------------
-- db_connection_manager.lua: luasql.mysql persistent connection manager
-- This file is a part of pk-engine library
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

local is_table,
      is_string
      = import 'lua-nucleo/type.lua'
      {
        'is_table',
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

local make_generic_connection_manager
      = import 'pk-engine/generic_connection_manager.lua'
      {
        'make_generic_connection_manager'
      }

local make_persistent_db_connector,
      make_db_connector
      = import 'pk-engine/db/persistent_db_connector.lua'
      {
        'make_persistent_db_connector',
        'make_db_connector'
      }

--------------------------------------------------------------------------------

local log, dbg, spam, log_error = make_loggers(
    "db/db_connection_manager", "DCM"
  )

--------------------------------------------------------------------------------

local create_persistent_db_connector = function(db_info)
  arguments(
      "table", db_info
    )

  return make_persistent_db_connector(make_db_connector(db_info))
end

local get_db_info_hash = function(db_info)
  arguments(
      "table", db_info
    )

  -- Intentionally not storing password.
  local id = 'db:' .. assert_is_string(db_info.db_name)
          .. ';user:' .. assert_is_string(db_info.login)

  local address = assert(db_info.address)
  if is_string(address) then
    id = id .. ";uds:" .. address
  else
    id = id .. ";tcp:" .. address.host .. ":" .. address.port
  end

  return id
end

local make_db_connection_manager = function()
  return make_generic_connection_manager(
      create_persistent_db_connector,
      get_db_info_hash
    )
end

return
{
  make_db_connection_manager = make_db_connection_manager;
}
