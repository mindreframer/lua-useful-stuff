--------------------------------------------------------------------------------
-- workarounds.lua: workarounds for sidereal problems
-- This file is a part of pk-engine library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------
--
-- WARNING: Run code here inside call()
--
--------------------------------------------------------------------------------
-- TODO: Get rid of these ASAP!
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
    "redis/workarounds",
    "BRW"
  )

--------------------------------------------------------------------------------

-- TODO: Replace with plain try() when this sidereal issue will be fixed:
--       http://github.com/silentbicycle/sidereal/issues#issue/2
local rtry = function(status, ok, err, ...)
  if ok == false and err ~= nil then
    ok = nil
  end
  return try(status, ok, err, ...)
end

-- TODO: SLOW! Replace with cache:hmset() when it will be fixed
--       http://github.com/silentbicycle/sidereal/issues#issue/3
local hmset_workaround = function(cache, key, t)
  local num_sets = 0

  -- TODO: Remove ping() when this will be fixed in sidereal
  --       http://github.com/silentbicycle/sidereal/issues#issue/7
  cache:ping() -- To force reconnection

  cache:pipeline()
    rtry("INTERNAL_ERROR", cache:multi())
      for k, v in pairs(t) do
        rtry(
            "INTERNAL_ERROR",
            cache:hset(key, assert(tostring(k)), assert(tostring(v)))
          )
        num_sets = num_sets + 1
      end
    rtry("INTERNAL_ERROR", cache:exec())
  cache:send_pipeline()

  rtry("INTERNAL_ERROR", cache:get_response()) -- multi
  for i = 1, num_sets do
    rtry("INTERNAL_ERROR", cache:get_response()) -- hset
  end
  rtry("INTERNAL_ERROR", cache:get_response()) -- exec
end

-- TODO: SLOW! Replace with cache:hgetall() when it will be fixed
--       http://github.com/silentbicycle/sidereal/issues#issue/3
-- Not atomic!
local hgetall_workaround = function(cache, key)
  local result = { }

  local keys = rtry("INTERNAL_ERROR", cache:hkeys(key))
  local vals = rtry("INTERNAL_ERROR", cache:hvals(key))

  assert(#keys == #vals)

  for i = 1, #keys do
    result[keys[i]] = vals[i]
  end

  return result
end

-- TODO: Generalize
-- TODO: Not actually a workaround
-- NOTE: Not atomic
local lpush_ilist = function(cache, key, t)
  -- TODO: Remove ping() when this will be fixed in sidereal
  --       http://github.com/silentbicycle/sidereal/issues#issue/7
  cache:ping() -- To force reconnection

  cache:pipeline()
  for i = 1, #t do
    rtry("INTERNAL_ERROR", cache:rpush(key, t[i]))
  end
  cache:send_pipeline()
  for i = 1, #t do
    rtry("INTERNAL_ERROR", cache:get_response()) -- rpush
  end
end

--------------------------------------------------------------------------------

return
{
  rtry = rtry;
  hmset_workaround = hmset_workaround;
  hgetall_workaround = hgetall_workaround;
  lpush_ilist = lpush_ilist;
}
