--------------------------------------------------------------------------------
-- run.lua: service runner
#{FILE_HEADER}
--------------------------------------------------------------------------------

pcall(require, 'luarocks.require') -- Ignoring errors

--------------------------------------------------------------------------------

require 'lua-nucleo.module'
require 'lua-nucleo.strict'

require = import 'lua-nucleo/require_and_declare.lua' { 'require_and_declare' }

exports -- Hack for WSAPI globals
{
  'main_func';
  'main_coro';
}

require 'wsapi.fastcgi'
require 'wsapi.request'

--------------------------------------------------------------------------------

local reopen_log_file
do
  local common_init_logging_to_file
        = import 'pk-core/log.lua'
        {
          'common_init_logging_to_file'
        }

  -- TODO: Make configurable!
  local LOG_FILE_NAME = "/var/log/#{PROJECT_NAME}-#{SERVICE_NAME}-service.log"

  local ok
  ok, reopen_log_file = common_init_logging_to_file(LOG_FILE_NAME)
end

--------------------------------------------------------------------------------

local log, dbg, spam, log_error
    = import 'pk-core/log.lua' { 'make_loggers' } (
        "#{SERVICE_NAME}/run", "#{SERVICE_NAME_SHORT}"
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

local make_config_manager
      = import '#{PROJECT_NAME}/internal_config_client.lua'
      {
        'make_config_manager'
      }

local INTERNAL_CONFIG_HOST,
      INTERNAL_CONFIG_PORT
      = import '#{PROJECT_NAME}/cluster/config.lua'
      {
        'INTERNAL_CONFIG_HOST',
        'INTERNAL_CONFIG_PORT'
      }

local fail,
      try,
      rethrow,
      call
      = import 'pk-core/error.lua'
      {
        'fail',
        'try',
        'rethrow',
        'call'
      }

local collect_all_garbage
      = import 'lua-nucleo/misc.lua'
      {
        'collect_all_garbage'
      }

local make_api_context_stub
      = import 'pk-engine/webservice/client_api/api_context_stub.lua'
      {
        'make_api_context_stub'
      }

local try_get_next_task_nonblocking,
      try_get_next_task_blocking
      = import 'pk-engine/hiredis/system.lua'
      {
        'try_get_next_task_nonblocking',
        'try_get_next_task_blocking'
      }

local TABLES = import '#{PROJECT_NAME}/db/tables.lua' ()

--------------------------------------------------------------------------------

log("loading #{SERVICE_NAME} 8")

--------------------------------------------------------------------------------

-- TODO: Get these from internal config
local SERVICE_ID = "#{PROJECT_NAME}:#{SERVICE_NAME}:1"
local COLLECT_INTERVAL = 30 * 60 -- integer seconds, must be > 1

local SYSTEM_ACTIONS = { }

SYSTEM_ACTIONS.reopen_log_file = function(api_context)
  log("reopening log file...")
  reopen_log_file()
  log("log file reopened")
end

SYSTEM_ACTIONS.shutdown = function(api_context)
  log("collecting garbage before shutdown...")
  collect_all_garbage()
  log("shutting down...")
  os.exit(0) -- TODO: BAD! This would not do proper GC etc!
end

local handle_system_action = function(action)
  log("attempting to execute system action", action)

  local handler = SYSTEM_ACTIONS[action]
  if not handler then
    log_error("WARNING: attempted to invoke unknown system action", action)
    return false
  end

  handler()

  return true
end

--------------------------------------------------------------------------------

local loop = function()

  local api_context = make_api_context_stub(
      assert(
        make_config_manager(
            INTERNAL_CONFIG_HOST,
            INTERNAL_CONFIG_PORT
          )
      ),
      TABLES,
      function() return fail("INTERNAL_ERROR", "no www game config here") end,
      function() return fail("INTERNAL_ERROR", "no www admin config here") end,
      { }
    )

  -- TODO: This is service stub
  local res, err = call(function() -- Just so try() will work properly

    local last_system_action_time = 0

    while true do
      local time_current = os.time()

      -- TODO: Insert some function here

      local time_to_wait = math.max(
          1, -- Not 0!
          math.min(
              (last_system_action_time + COLLECT_INTERVAL) - time_current,
              COLLECT_INTERVAL
            )
        )

      spam("waiting for", time_to_wait, "seconds before next cycle")

      last_system_action_time = time_current

      local action = try_get_next_task_blocking(
          api_context,
          SERVICE_ID,
          time_to_wait
        )
      if action then
        handle_system_action(action)
      end

      collectgarbage()
    end
  end)

  if not res then
    log_error("error:", err)
  end

  log("loop: done")

  assert(res, err)

end

--------------------------------------------------------------------------------

return
{
  loop = loop;
}
