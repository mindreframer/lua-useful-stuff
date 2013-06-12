--------------------------------------------------------------------------------
-- db/info.lua: db introspection tools
-- This file is a part of pk-engine library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
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

--------------------------------------------------------------------------------

local log, dbg, spam, log_error = make_loggers("db/info", "DBI")

--------------------------------------------------------------------------------

local list_db_tables = function(db_conn)
  arguments(
      "userdata", db_conn
    )

  local cursor, err = db_conn:execute("SHOW TABLES")
  if not cursor then
    log_error("SHOW TABLES failed:", err)
    return nil, err
  end

  local result = { }
  local data = cursor:fetch()
  while data ~= nil do
    result[#result + 1] = assert_is_string(data)
    data = cursor:fetch()
  end

  cursor:close()

  return result
end

--------------------------------------------------------------------------------

return
{
  list_db_tables = list_db_tables;
}
