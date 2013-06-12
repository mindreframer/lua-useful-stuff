--------------------------------------------------------------------------------
-- cron.lua: schedule cron
-- This file is a part of pk-engine library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------

local make_loggers = import 'pk-core/log.lua' { 'make_loggers' }
local log, dbg, spam, log_error = make_loggers("cron", "CRN")

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

local tclone
      = import 'lua-nucleo/table-utils.lua'
      {
        'tclone'
      }

local heartbeat_put
      = import 'pk-engine/srv/heartbeat/client.lua'
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

--------------------------------------------------------------------------------

-- TODO: Maybe it's not a good realization - refactor, write tests and move to lua-nucleo
local permute = function(t, n)
  arguments(
      "table", t
    )
  optional_arguments(
      "number", n
    )

  n = n or #t

  for i = 1, n - 1 do
    local j = math.random(i, n)
    if i ~= j then
      t[i], t[j] = t[j], t[i]
    end
  end

  return t
end


--------------------------------------------------------------------------------

-- Note: There are no arguments to choose exactly '2'
local MAX_HB_SRV_LOOPS = 2

local schedule_cron = function(
    context,
    cron_properties,
    cron_tp_channel
  )
  arguments(
      "table",  context,
      "table",  cron_properties,
      "string", cron_tp_channel
    )

  local cron = assert_is_table(make_cron(cron_properties))

  local time = os.time()

  local next_occurrence, err = cron:get_next_occurrence(time)
  if not next_occurrence then
    return nil, "schedule_cron: get_next_occurrence failed: " .. err
  end

  local timeout = next_occurrence - time
  assert(timeout > 0)

  do -- successfully put to random heartbeat server from group

    -- TODO: Don't use private member!
    local cron_group = assert_is_table(context.config_manager_:get_cron_group_info(
          assert_is_string(cron_properties.group)
        ))

    local heartbeat_servers = tclone(cron_group.heartbeat_servers)
    permute(heartbeat_servers)

    local num_heartbeats = #heartbeat_servers

    local sent = false
    for loops = 1, MAX_HB_SRV_LOOPS do
      for i = 1, num_heartbeats do
        local heartbeat_srv_name = assert_is_string(heartbeat_servers[i])

        local conn, id = context:acquire_heartbeat_connection(heartbeat_srv_name)
        if conn then
          sent = heartbeat_put(conn, timeout, cron_tp_channel, args_save(
              "cron",
              timeout,
              cron_properties,
              cron_tp_channel
            ))
          context:unacquire_connection(conn, id)
          conn, id = nil, nil

          if sent then break end
        else
          log_error("schedule_cron: heartbeat server `"
              .. heartbeat_srv_name .. "' is not valid"
            )
        end
      end
      if sent then break end
    end

    if not sent then
      return nil, "schedule_cron: can't put to heartbeat: no valid heartbeat servers"
    end
  end

  return true
end

return
{
  schedule_cron = schedule_cron;
}
