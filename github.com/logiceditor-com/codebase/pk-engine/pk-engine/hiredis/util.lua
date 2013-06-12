--------------------------------------------------------------------------------
-- util.lua: hiredis utilities
-- This file is a part of pk-engine library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------

local hiredis = require 'hiredis'

--------------------------------------------------------------------------------

local log, dbg, spam, log_error
      = import 'pk-core/log.lua' { 'make_loggers' } (
          "pk-engine/hiredis/util", "HRU"
        )

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

local try
      = import 'pk-core/error.lua'
      {
        'try'
      }

--------------------------------------------------------------------------------

local try_unwrap = function(error_id, res, ...)
  return try(
      error_id,
      hiredis.unwrap_reply(
          try(error_id, res, ...)
        )
    )
end

local log_unwrap = function(...)
  local res, err = hiredis.unwrap_reply(...)
  if not res then
    log_error("unwrap failed: ", err)
  end
  return res
end
--------------------------------------------------------------------------------

return
{
  try_unwrap = try_unwrap;
  log_unwrap = log_unwrap;
}
