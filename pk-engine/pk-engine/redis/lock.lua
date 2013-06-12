--------------------------------------------------------------------------------
-- lock.lua: distributed locks in Redis
-- This file is a part of pk-engine library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------
--
-- WARNING: Run code here inside call()
--
--------------------------------------------------------------------------------
-- TODO: Implement some GC-ing of locks?
--------------------------------------------------------------------------------

local socket = require 'socket'

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

local pack
      = import 'lua-nucleo/args.lua'
      {
        'pack'
      }

local fail,
      try
      = import 'pk-core/error.lua'
      {
        'fail',
        'try'
      }

local make_loggers
      = import 'pk-core/log.lua'
      {
        'make_loggers'
      }

--------------------------------------------------------------------------------

local log, dbg, spam, log_error = make_loggers(
    "redis/lock",
    "RLK"
  )

--------------------------------------------------------------------------------

-- See http://code.google.com/p/redis/wiki/SetnxCommand

local lock_str = function(etime)
  return ("%.55g"):format(etime)
end

-- Returns false, etime if lock was not acquired. True otherwise.
local redis_attempt_lock = function(conn, lock, etime, time_current)
  arguments(
      -- "object", conn,
      "string", lock,
      "number", etime
    )

  optional_arguments("number", time_current)

  local etime_str = lock_str(etime)

  local did_lock, err = conn:setnx(lock, etime_str)
  -- TODO: HACK. Remove when sidereal is fixed
  if not did_lock and err then
    did_lock = nil
  end

  if did_lock == nil then
    log_error("redis_attempt_lock", lock, "setnx failed:", err)
    return nil, "redis_attempt_lock failed: " .. tostring(err)
  end

  if did_lock then
    return true -- We acquired lock
  end

  -- Check for stale lock
  local expected_etime_str, err = conn:get(lock)
  if not expected_etime_str then
    log_error("redis_attempt_lock", lock, "get failed:", err)
    return nil, "redis_attempt_lock failed: " .. tostring(err)
  end

  local expected_etime = tonumber(expected_etime_str)
  if not expected_etime then
    local err = "redis_attempt_lock " .. lock
      .. " get returned bad expected_etime: " .. tostring(expected_etime_str)
    log_error(err)
    return nil, "redis_attempt_lock failed: ".. tostring(err)
  end

  time_current = time_current or socket.gettime()
  if expected_etime > time_current then
    return false, expected_etime -- Truly locked
  end

  dbg("redis_attempt_lock stale lock", lock, "detected", expected_etime, time_current)

  local actual_etime_str, err = conn:getset(lock, etime_str)
  if not actual_etime_str then
    log_error("redis_attempt_lock", lock, "getset failed:", err)
    return nil, "redis_attempt_lock failed: " .. tostring(err)
  end

  local actual_etime = tonumber(actual_etime_str)
  if not actual_etime then
    local err = "redis_attempt_lock " .. lock
      .. " getset returned bad actual_etime: " .. tostring(actual_etime_str)
    log_error(err)
    return nil, "redis_attempt_lock failed: " .. tostring(err)
  end

  if actual_etime ~= expected_etime then
    dbg("redis_attempt_lock stale lock", lock, "stolen from under our nose (no problem)")
    return false, actual_etime -- Someone locked before us
  end

  return true -- We managed to takeover a stale lock
end

-- Returns false if lock time is expired or lock was not found
local redis_unlock = function(conn, lock, etime, time_current)
  time_current = time_current or socket.gettime()
  arguments(
      -- "object", conn,
      "string", lock,
      "number", etime
    )

  if etime <= time_current then
    log_error("WARNING: lock", lock, "time expired before unlock", etime, time_current)
    return false -- Lock may be taken over already, not doing anything
  end

  local res, err = conn:del(lock)
  -- TODO: HACK. Remove when sidereal is fixed
  if not res and err then
    res = nil
  end

  if res == nil then
    log_error("redis_unlock", lock, "del failed:", err)
    return nil, "redis_unlock failed: " .. tostring(err)
  end

  if res == 0 then
    log_error("WARNING: can't find lock to unlock:", lock)
    return false
  end

  if res ~= 1 then
    log_error("redis_unlock", lock, "weird del result:", res)
    -- ignoring error
  end

  return true
end

-- TODO: Generalize
local error_handler = function(msg)
  log_error(debug.traceback(msg))
  return msg
end

local function do_with_redis_lock(conn, lock, etime, fn)
  arguments(
      -- "object", conn,
      "string", lock,
      "number", etime,
      "function", fn
    )
  -- TODO: Inferior, fragile and slow!
  --       We need to SUBSCRIBE to the unlock event and yield control to other workers.

  local did_lock, existing_etime = redis_attempt_lock(conn, lock, etime)
  if did_lock == nil then
    local err = existing_etime
    log_error("do_with_redis_lock: failed to take lock", lock, ":", err)
    return nil, "do_with_redis_lock failed: " .. tostring(err)
  end

  if not did_lock then
    if etime < existing_etime then
      local err = "do_with_redis_lock: lock " .. lock .. " will be unlocked at "
        .. lock_str(existing_etime)
        .. ", which is later than our own etime " .. lock_str(etime)
      log_error(err)
      return nil, "do_with_redis_lock failed: " .. tostring(err)
    end

    local time_to_sleep = math.max(existing_etime - socket.gettime(), 0.001) -- TODO: WTF?!?!

    dbg("do_with_redis_lock: sleeping for", time_to_sleep, "until unlock of", lock)
    assert(time_to_sleep > 0, "bad time to sleep")
    socket.sleep(time_to_sleep) -- TODO: BAD!

    return do_with_redis_lock(conn, lock, etime, fn) -- Trying again
  end

  local nargs, args = pack(xpcall(fn, error_handler))

  local res, err = redis_unlock(conn, lock, etime)
  if res == nil then
    log_error("do_with_redis_lock: unlock of ", lock, "failed:", err)
    -- Continuing anyway
  end

  if args[1] == false then
    local err = args[2]
    log_error("do_with_redis_lock: callback failed:", err)
    if is_string(err) then
      err = "do_with_redis_lock failed: " .. err
    end
    return nil, err
  end

  return unpack(args, 2, nargs)
end

-- Note: TTLs less than 3 seconds are likely to produce stale locks
local do_with_redis_lock_ttl = function(conn, lock, ttl, fn)
  arguments(
      -- "object", conn,
      "string", lock,
      "number", ttl,
      "function", fn
    )
  assert(ttl > 0)

  return do_with_redis_lock(conn, lock, socket.gettime() + ttl + 1, fn)
end

--------------------------------------------------------------------------------

return
{
  redis_attempt_lock = redis_attempt_lock;
  redis_unlock = redis_unlock;
  do_with_redis_lock = do_with_redis_lock;
  do_with_redis_lock_ttl = do_with_redis_lock_ttl;
}
