--------------------------------------------------------------------------------
-- system.lua: system Redis job queue stuff
-- This file is a part of pk-engine library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------
--
-- WARNING: Run code here inside call()
--
--------------------------------------------------------------------------------

local hiredis = require 'hiredis'

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

local tilistofrecordfields,
      tipermute_inplace
      = import 'lua-nucleo/table-utils.lua'
      {
        'tilistofrecordfields',
        'tipermute_inplace'
      }

local fail,
      try,
      rethrow
      = import 'pk-core/error.lua'
      {
        'fail',
        'try',
        'rethrow'
      }

local do_with_redis_lock_ttl
      = import 'pk-engine/redis/lock.lua'
      {
        'do_with_redis_lock_ttl'
      }

local try_unwrap
      = import 'pk-engine/hiredis/util.lua'
      {
        'try_unwrap'
      }

--------------------------------------------------------------------------------

local log, dbg, spam, log_error
    = import 'pk-core/log.lua' { 'make_loggers' } (
        "redis/system", "RSY"
      )

--------------------------------------------------------------------------------

local DB_NAME = "system"
local TASK_LIST_KEY_PREFIX = "task:"

local LOCK_NAME = "lock:task:all"
local LOCK_TTL = 3

--------------------------------------------------------------------------------

local system_redis = function(api_context)
  local redis = api_context:hiredis()
  return redis[DB_NAME](redis)
end

local task_queue_key = function(service_id)
  return TASK_LIST_KEY_PREFIX .. service_id
end

--------------------------------------------------------------------------------

local get_next_task_nonblocking = function(conn, service_id)
  arguments(
      -- "object", conn,
      "string", service_id
    )

  local list_key = task_queue_key(service_id)

  conn:command("PING") -- ignoring errors

  local res, err = hiredis.unwrap_reply(conn:command("LPOP", list_key))

  if not res then
    log_error(
        "get_next_task_nonblocking for service_id",
        service_id, "failed:", err
      )
    return nil, "get_task_nonblocking failed: " .. tostring(err)
  end

  if res == hiredis.NIL then
    return false -- Not found
  end

  return res
end

local try_get_next_task_nonblocking = function(api_context, service_id)
  arguments(
      "table", api_context,
      "string", service_id
    )

  return try(
      "INTERNAL_ERROR",
      get_next_task_nonblocking(
          system_redis(api_context),
          service_id
        )
    )
end

--------------------------------------------------------------------------------

-- Set timeout to 0 to block forever. Timeout is in integer seconds.
-- Returns false if timeout expired
-- Returns nil, err on error
local get_next_task_blocking = function(cache, service_id, timeout)
  arguments(
      -- "object", cache,
      "string", service_id,
      "number", timeout
    )

  local list_key = task_queue_key(service_id)

  cache:command("PING") -- ignoring errors

  local res, err = hiredis.unwrap_reply(cache:command("BLPOP", list_key, timeout))

  if not res then
    log_error(
        "get_next_task_nonblocking for service_id",
        service_id, "failed:", err
      )
    return nil, "get_task_nonblocking failed: " .. tostring(err)
  end

  if res == hiredis.NIL then
    return false -- timeout
  end

  local actual_list_key = res[1]
  local value = res[2]

  assert(actual_list_key == list_key, "sanity check")

  return value
end

-- Set timeout to 0 to block forever. Timeout is in integer seconds.
-- Returns false if timeout expired
-- Fails on error
local try_get_next_task_blocking = function(api_context, service_id, timeout)
  arguments(
      "table", api_context,
      "string", service_id,
      "number", timeout
    )
  return try(
      "INTERNAL_ERROR",
      get_next_task_blocking(
          system_redis(api_context),
          service_id,
          timeout
        )
    )
end

--------------------------------------------------------------------------------

local push_task = function(conn, service_id, task_data)

  conn:command("PING") -- ignoring errors

  local res, err = hiredis.unwrap_reply(
      conn:command("RPUSH", task_queue_key(service_id), task_data)
    )

  if res == nil then
    log_error("failed to push task to service", service_id, ":", err)
    return nil, "push_task failed: " .. (tostring(err) or nil)
  end

  return res
end

local try_push_task = function(api_context, service_id, task_data)
  arguments(
      "table", api_context,
      "string", service_id,
      "string", task_data
    )

  local cache = system_redis(api_context)
  try("INTERNAL_ERROR", push_task(cache, service_id, task_data))
end

--------------------------------------------------------------------------------

local try_flush_tasks = function(api_context, service_id)
  arguments(
      "table", api_context,
      "string", service_id
    )
  local cache = system_redis(api_context)
  local list_key = task_queue_key(service_id)
  cache:command("PING") -- ignoring errors
  try_unwrap("INTERNAL_ERROR", cache:command("LTRIM", list_key, 1, 0))
end

--------------------------------------------------------------------------------

return
{
  get_next_task_nonblocking = get_next_task_nonblocking;
  get_next_task_blocking = get_next_task_blocking;
  push_task = push_task;
  --
  try_get_next_task_nonblocking = try_get_next_task_nonblocking;
  try_get_next_task_blocking = try_get_next_task_blocking;
  try_push_task = try_push_task;
  --
  try_flush_tasks = try_flush_tasks;
}
