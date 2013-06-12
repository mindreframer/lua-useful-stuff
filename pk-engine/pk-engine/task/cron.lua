--------------------------------------------------------------------------------
-- cron_task.lua: spawns cron task
-- This file is a part of pk-engine library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--
-- We implemented cron task spawning using this task in generalization purposes.
-- Once raised, this task puts itself into heartbeat's query
-- and puts cronning task to task processor (may differ from cron's TP).
--
--------------------------------------------------------------------------------

local make_loggers = import 'pk-core/log.lua' { 'make_loggers' }
local log, dbg, spam, log_error = make_loggers("task/cron", "TCR")

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

local assert_is_string,
      assert_is_number,
      assert_is_table
      = import 'lua-nucleo/typeassert.lua'
      {
        'assert_is_string',
        'assert_is_number',
        'assert_is_table'
      }

local do_atomic_op_with_file
      = import 'lua-aplicado/filesystem.lua'
      {
        'do_atomic_op_with_file'
      }

local channel_put
      = import 'pk-engine/srv/channel/client.lua'
      {
        'put'
      }

local args_save
      = import 'pk-engine/task_processor/task_processor.lua'
      {
        'args_save'
      }

local make_cron
      = import 'pk-engine/crontab.lua'
      {
        'make_cron'
      }

local schedule_cron
      = import 'pk-engine/cron.lua'
      {
        'schedule_cron'
      }

--------------------------------------------------------------------------------

local check_timeout = function(log_file_name, timeout)
  arguments(
      "string", log_file_name,
      "number", timeout
    )

  --spam("check_timeout: start", timeout, log_file_name)

  local check_and_update_timeout = function(log_file)
    local size, err = log_file:seek("end")
    if not size then
      return nil, err
    end

    local time = os.time()
    local stime = tostring(time)
    local timestamp_size = #stime

    -- check last timestamp in file
    if size > 0 then
      local res, err = log_file:seek("end", -(timestamp_size + 1) )
      if not res then
        return nil, err
      end

      do
        local eol, err = log_file:read(1)
        if not eol then
          return nil, "error reading end-of-line before timestamp"
        end
        if eol ~= "\n" then
          return nil, "invalid cron log file format, `" .. eol .. "' instead of end-of-line"
        end
      end

      local read, err = log_file:read(timestamp_size)
      if not read then
        return nil, "error reading timestamp: " .. err
      end

      local prev_time = tonumber(read)
      if not prev_time then
        return nil, "invalid timestamp: `" .. read .. "'"
      end

      --spam("check_timeout: time, prev_time, time - prev_time + 1",
      --    time,
      --    prev_time,
      --    time - prev_time
      --  )

      if time - prev_time + 1 < timeout then
        return nil, "too short timeout: " .. time - prev_time .. " instead of " .. timeout
      end
    else
      --spam("check_timeout: zero file size")
    end

    return log_file:write("\n", stime)
  end

  return do_atomic_op_with_file(log_file_name, check_and_update_timeout)
end

local add_task_to_task_processor = function(context, task_processor_channel, task_name, ...)
  arguments(
      "table",  context,
      "string", task_processor_channel,
      "string", task_name
    )

  local conn, id = context:acquire_channel_connection(task_processor_channel)
  if not conn then
    local err = id
    return nil, err
  end

  local res, err = channel_put(conn,  task_processor_channel, args_save(task_name, ...))

  context:unacquire_connection(conn, id)
  conn, id = nil, nil

  return res, err
end

local run = function(
    context,
    previous_timeout,
    cron_properties,
    cron_tp_channel
  )
  arguments(
      "table",  context,
      "number", previous_timeout,
      "table",  cron_properties,
      "string", cron_tp_channel
    )

  --spam("cron task:", cron_properties)

  local timeout_checked, err_check_timeout = check_timeout(
      assert_is_string(cron_properties.log),
      assert_is_number(previous_timeout)
    )

  local task_added, err_add_task

  if timeout_checked then
    task_added, err_add_task = add_task_to_task_processor(
        context,
        assert_is_string(cron_properties.channel),
        assert_is_string(cron_properties.task),
        unpack(assert_is_table(cron_properties.task_args))
      )
    if not task_added then
      log_error("cron: add_task_to_task_processor failed: " .. err_add_task)
    end
  else
    log_error("cron: check_timeout failed: " .. err_check_timeout)
  end


  local cron_scheduled, err_schedule_cron = schedule_cron(
      context,
      cron_properties,
      cron_tp_channel
    )
  if not cron_scheduled then -- critical, this cron won't run anymore
    error("cron: schedule_cron failed: " .. err_schedule_cron)
  end


  if not timeout_checked then
    return nil, "cron: check_timeout failed: " .. err_check_timeout
  elseif not task_added then
    return nil, "cron: add_task_to_task_processor failed: " .. err_add_task
  end

  return true
end

--------------------------------------------------------------------------------

return
{
  run = run;
}
