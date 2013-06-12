--------------------------------------------------------------------------------
-- echo.lua: simplest test task
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

local make_loggers
      = import 'pk-core/log.lua'
      {
        'make_loggers'
      }

local try_unwrap
      = import 'pk-engine/hiredis/util.lua'
      {
        'try_unwrap'
      }

--------------------------------------------------------------------------------

local log, dbg, spam, log_error
    = import 'pk-core/log.lua' { 'make_loggers' } (
        "task/echo", "TEC"
      )

--------------------------------------------------------------------------------

local run = function(api_context, db_name, input_string)
  arguments(
      "table", api_context,
      "string", db_name,
      "string", input_string
    )

  log("echo task got input string:", input_string)

  local redis = api_context:hiredis()
  local db = redis[db_name](redis)

  try_unwrap(
      "INTERNAL_ERROR",
      db:command("PING")
    )

  try_unwrap(
      "INTERNAL_ERROR",
      db:command("RPUSH", "test_task_key", input_string)
    )
  return true
end

--------------------------------------------------------------------------------

return
{
  run = run;
}
