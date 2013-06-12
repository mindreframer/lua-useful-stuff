--------------------------------------------------------------------------------
-- error.lua: error handling convenience wrapper
-- This file is a part of pk-core library
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

local is_table
      = import 'lua-nucleo/type.lua'
      {
        'is_table'
      }

local unique_object
      = import 'lua-nucleo/misc.lua'
      {
        'unique_object'
      }

local make_loggers
      = import 'pk-core/log.lua'
      {
        'make_loggers'
      }

--------------------------------------------------------------------------------

local log, dbg, spam, log_error = make_loggers("pk-core/error", "ERR")

--------------------------------------------------------------------------------

local error_tag = unique_object()

local is_error_object = function(err)
  return not not (is_table(err) and err[1] == error_tag)
end

local error_handler_for_call = function(msg)
  if not is_error_object(msg) then
    msg = debug.traceback(msg)
    log_error(msg)
  else
    spam("caught: ", debug.traceback(msg[2])) -- Required for debugging
  end
  return msg
end

local create_error_object = function(error_id)
  return { error_tag, error_id }
end

local get_error_id = function(err)
  if is_error_object(err) then
    return err[2]
  end
  return nil
end

local throw = function(error_id)
  return error(create_error_object(error_id))
end

local pcall_adaptor_for_call = function(status, ...)
  if not status then
    local err = (...)

    local error_id = get_error_id(err)
    if error_id ~= nil then
      return nil, error_id
    end

    return error(err) -- Not our error, rethrow
  end
  return ... -- TODO: Shouldn't we return true here?
end

--------------------------------------------------------------------------------

-- TODO: HEAVY! Optimize?
local call = function(fn, ...)
  local nargs, args = select("#", ...), { ... }
  return pcall_adaptor_for_call(
      xpcall(
          function()
            return fn(unpack(args, 1, nargs))
          end,
          error_handler_for_call
        )
    )
end

local fail = function(error_id, msg)
  log_error(msg)
  throw(error_id)
end

local try = function(error_id, result, err, ...)
  if result == nil then
    fail(error_id, err)
  end

  return result, err, ...
end

local rethrow = function(error_id, err)
  if not is_error_object(err) then
    return fail(error_id, err)
  end
  error(err) -- Rethrowing our error, ignoring error_id
end

--------------------------------------------------------------------------------

return
{
  call = call;
  try = try;
  fail = fail;
  rethrow = rethrow;
  --
  error_handler_for_call = error_handler_for_call;
}
