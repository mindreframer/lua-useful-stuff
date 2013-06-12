--------------------------------------------------------------------------------
-- run.lua: site wsapi runner
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

require 'wsapi.request'
require 'wsapi.util'

--------------------------------------------------------------------------------

local reopen_log_file
do
  local common_init_logging_to_file
        = import 'pk-core/log.lua'
        {
          'common_init_logging_to_file'
        }

  -- TODO: Make configurable!
  local LOG_FILE_NAME = "/var/log/#{PROJECT_NAME}-#{API_NAME}-wsapi.log"

  local ok
  ok, reopen_log_file = common_init_logging_to_file(LOG_FILE_NAME)
end

--------------------------------------------------------------------------------

local log, dbg, spam, log_error
    = import 'pk-core/log.lua' { 'make_loggers' } (
        "#{API_NAME}/wsapi", "#{API_NAME_SHORT}"
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

local assert_is_function
      = import 'lua-nucleo/typeassert.lua'
      {
        'assert_is_function'
      }

local do_nothing
      = import 'lua-nucleo/functional.lua'
      {
        'do_nothing'
      }

local create_path_to_file
      = import 'lua-aplicado/filesystem.lua'
      {
        'create_path_to_file'
      }

local make_request_manager_using_handlers
      = import 'pk-engine/webservice/request_manager.lua'
      {
        'make_request_manager_using_handlers'
      }

local fcgi_wsapi_runner_stop,
      fcgi_wsapi_runner_run
      = import 'pk-engine/webservice/fcgi_wsapi_runner.lua'
      {
        'stop',
        'run'
      }

local try_unwrap,
      log_unwrap
      = import 'pk-engine/hiredis/util.lua'
      {
        'try_unwrap',
        'log_unwrap'
      }

local try_send_system_message
      = import 'pk-engine/webservice/client_api/system_message.lua'
      {
        'try_send_system_message'
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

local HANDLERS,
      URL_HANDLER_WRAPPER
      = import 'handlers.lua'
      {
        'HANDLERS',
        'URL_HANDLER_WRAPPER'
      }

local EXTENSIONS
      = import 'extensions.lua'
      {
        'EXTENSIONS'
      }

local ADD_EXTENSIONS =
{
  import '#{PROJECT_NAME}/extensions/extensions.lua' { 'EXTENSIONS' };
--[[BLOCK_START:PK_WEBSERVICE]]
  import 'pk-webservice/extensions.lua' { 'EXTENSIONS' };
--[[BLOCK_END:PK_WEBSERVICE]]
}

local tclone,
      tijoin_many
      = import 'lua-nucleo/table-utils.lua'
      {
        'tclone',
        'tijoin_many'
      }

local random_seed_from_string
      = import 'lua-aplicado/random.lua'
      {
        'random_seed_from_string'
      }

-------------------------------------------------------------------------------

log("loading wsapi-runner (#{API_NAME} 11)")

-------------------------------------------------------------------------------

-- TODO: to lua-nucleo
local tkvmap_unpack = function(fn, t, ...)
  local r = { }
  for k, v in pairs(t) do
    k, v = fn(k, ...), fn(v, ...)

    if k ~= nil and v ~= nil then
      r[#r + 1] = k
      r[#r + 1] = v
    end
  end
  return unpack(r)
end

-------------------------------------------------------------------------------

-- TODO: Get rid of these variables in wsapi_env.
local make_stub_wsapi_env = function()
  local wsapi_env = wsapi.util.make_env_get()
  wsapi_env.PK_CONFIG_HOST = wsapi_env.PK_CONFIG_HOST or INTERNAL_CONFIG_HOST
  wsapi_env.PK_CONFIG_PORT = wsapi_env.PK_CONFIG_PORT or INTERNAL_CONFIG_PORT
  return wsapi_env
end

-------------------------------------------------------------------------------

local SERVICE_NAME = "#{PROJECT_NAME}.#{API_NAME}"
local SYSTEM_ACTION_SERVICE_NAME = "#{API_NAME}" -- TODO: ?! WTF? Remove.
local NODE_ID = nil
local PID = nil

local ZMQ_CONTROL_SOCKET_URL = nil -- Hack.

-- TODO: Bad. Use some singleton to get this: many places in code will want it.
local ZMQ_CONTEXT = zmq.init(1)

-- Should live between calls to run()
local request_manager = make_request_manager_using_handlers(
    HANDLERS, make_config_manager, SERVICE_NAME
  )

local api_context_wrap = function(fn)
  arguments(
      "function", fn
    )

  return function(
      request_manager,
      wsapi_env,
      ...
    )
    arguments(
        "table", request_manager,
        "table", wsapi_env
      )

    return URL_HANDLER_WRAPPER:do_with_api_context(
        request_manager:get_context(wsapi_env), fn, ...
      )
  end
end

-- TODO: All this stuff must be generalized (in unwrapped form)

local register_service = api_context_wrap(function(
    api_context, service_name, node_id, pid, service_info
  )
  arguments(
      "table",  api_context,
      "string", service_name,
      "string", node_id,
      "number", pid,
      "table",  service_info
    )

  log(
      "registering service",
      service_name, node_id, pid
    )
  api_context:hiredis():system():command("PING")
  log_unwrap(
      "INTERNAL_ERROR",
      api_context:hiredis():system():command(
          "HMSET",
          "pk-services:info:" .. service_name .. ":" .. node_id .. ":" .. pid,
          tkvmap_unpack(tostring, service_info)
        )
    )

  log_unwrap(
      "INTERNAL_ERROR",
      api_context:hiredis():system():command(
          "HMSET",
          "pk-services:info:" .. service_name .. ":" .. node_id .. ":" .. pid,
          "name", service_name,
          "node_id", node_id,
          "pid", pid,
          "time_now", socket.gettime()
        )
    )

  local added = log_unwrap(
      api_context:hiredis():system():command(
          "SADD",
          "pk-services:running",
          service_name .. ":" .. node_id .. ":" .. pid
        )
    )

  if not added or added == 0 then
    log_error("WARNING: pid pre-existed for", service_name, node_id, pid)
    -- Ignoring error.
  end

  return true
end)

local unregister_service = api_context_wrap(function(
    api_context, service_name, node_id, pid, service_info
  )
  arguments(
      "table",  api_context,
      "string", service_name,
      "string", node_id,
      "number", pid,
      "table",  service_info
    )

  log("unregistering service", service_name, node_id, pid)

  local time_now = socket.gettime()

  -- Note that we do not remove service info.
  -- Assuming we will want to study it later.
  api_context:hiredis():system():command("PING")
  log_unwrap(
      api_context:hiredis():system():command(
          "HMSET",
          "pk-services:info:" .. service_name .. ":" .. node_id .. ":" .. pid,
          tkvmap_unpack(tostring, service_info)
        )
    )

  log_unwrap(
      api_context:hiredis():system():command(
          "HMSET",
          "pk-services:info:" .. service_name .. ":" .. node_id .. ":" .. pid,
          "time_now", time_now,
          "time_shutdown", time_now
        )
    )

  log_unwrap(
      api_context:hiredis():system():command(
          "SREM",
          "pk-services:running",
          service_name .. ":" .. node_id .. ":" .. pid
        )
    )

  return true
end)

local update_service_info = api_context_wrap(function(
    api_context,
    service_name, node_id, pid, service_info
  )
  arguments(
      "table",  api_context,
      "string", service_name,
      "string", node_id,
      "number", pid,
      "table",  service_info
    )

  log("updating service info", service_name, node_id, pid)
  api_context:hiredis():system():command("PING")
  log_unwrap(
      api_context:hiredis():system():command(
          "HMSET",
          "pk-services:info:" .. service_name .. ":" .. node_id .. ":" .. pid,
          tkvmap_unpack(tostring, service_info)
        )
    )

  -- TODO: Should be done in the same call as above
  -- TODO: Remove copy-paste with register()
  log_unwrap(
      api_context:hiredis():system():command(
          "HMSET",
          "pk-services:info:" .. service_name .. ":" .. node_id .. ":" .. pid,
          "name", service_name,
          "node_id", node_id,
          "pid", pid,
          "time_now", socket.gettime()
        )
    )

  -- Just in case someone trigger-happy deleted us.
  log_unwrap(
      api_context:hiredis():system():command(
          "SADD",
          "pk-services:running",
          service_name .. ":" .. node_id .. ":" .. pid
        )
    )

  return true
end)

local system_action_handlers
do
  system_action_handlers = { }

  system_action_handlers.reopen_log_file = function()
    log("reopening log file...")
    reopen_log_file()
    log("log file reopened")

    return true
  end

  system_action_handlers.shutdown = function()
    log("shutting down...")
    unregister_service(
        request_manager, make_stub_wsapi_env(),
        assert(SERVICE_NAME),
        assert(NODE_ID),
        assert(PID),
        request_manager:get_service_info()
      )
    fcgi_wsapi_runner_stop()
    log("shutdown sequence executed")

    return true
  end

  system_action_handlers.update_service_info = function()
    log("updating service info...")
    update_service_info(
        request_manager, make_stub_wsapi_env(),
        assert(SERVICE_NAME),
        assert(NODE_ID),
        assert(PID),
        request_manager:get_service_info()
      )
    log("service info updated")

    return true
  end
end

local run_once
do
  local make_current_node_system_action_executor
  do
    -- TODO: Allow execution in other nodes and services?
    -- Does not send message to this process.
    local execute = function(self, action, ...)
      method_arguments(
          self,
          "string", action
        )
      URL_HANDLER_WRAPPER:do_with_api_context(
          request_manager:get_context(make_stub_wsapi_env()),
          function(api_context, ...)
            try_send_system_message(
                -- Don't send msg to this process
                assert(ZMQ_CONTROL_SOCKET_URL),
                api_context:raw_internal_config_manager(),
                api_context:raw_redis_manager(),
                assert(ZMQ_CONTEXT),
                assert(SYSTEM_ACTION_SERVICE_NAME),
                assert(NODE_ID),
                action,
                ...
              )
            return true
          end,
          ...
        )
      return true
    end

    make_current_node_system_action_executor = function()

      return
      {
        execute = execute;
        --
        conn_ = nil; -- TODO: Adapt persistent_connection for zmq?
      }
    end
  end

  local make_current_process_system_action_executor
  do
    local execute = function(self, action, ...)
      method_arguments(
          self,
          "string", action
        )

      local handler = system_action_handlers[action]
      if not handler then
        local err = "unknown system action: " .. tostring(action)
        log_error(err)
        return nil, err
      end

      return handler(...)
    end

    make_current_process_system_action_executor = function()

      return
      {
        execute = execute;
      }
    end
  end

  run_once = function(
      request_manager,
      wsapi_env,
      service_name,
      node_id,
      pid
    )
    run_once = do_nothing

    -- Hack.
    request_manager:extend_context(
        wsapi_env,
        "current_node_system_action_executor",
        make_current_node_system_action_executor
      )
    request_manager:extend_context(
        wsapi_env,
        "current_process_system_action_executor",
        make_current_process_system_action_executor
      )

    local to_precache = { }

    local extensions = tclone(EXTENSIONS)
    for i = 1, #ADD_EXTENSIONS do
      extensions = tijoin_many(extensions, ADD_EXTENSIONS[i])
    end

    for i = 1, #extensions do
      local ext_info = extensions[i]

      local ext_data = import(ext_info[1]) ()

      request_manager:extend_context(
          wsapi_env,
          ext_info.name,
          assert(ext_data.factory)
        )

      if ext_data.PRECACHE then
        to_precache[#to_precache + 1] = ext_info.name
      end

      if ext_data.system_action_handlers then
        for k, v in pairs(ext_data.system_action_handlers) do
          assert(
              not system_action_handlers[k],
              "duplicate system action handler"
            )
          local handler = api_context_wrap(assert_is_function(v))
          system_action_handlers[k] = function(...)
            return handler(
                request_manager, make_stub_wsapi_env(), ...
              )
          end
        end
      end
    end

    -- Doing in a second loop to help resolve interdependencies.
    for i = 1, #to_precache do
      assert(request_manager:get_context_extension(wsapi_env, to_precache[i]))
    end

    register_service(
        request_manager, wsapi_env,
        service_name, node_id, pid,
        request_manager:get_service_info()
      )
  end
end

local run = function(wsapi_env)
  --log("REQUEST", wsapi_env.PATH_INFO) -- TODO: Log full URL?
  collectgarbage("step")
  return request_manager:handle_request(wsapi_env)
end

--------------------------------------------------------------------------------

local loop = function(node_id)
  arguments("string", node_id)

  -- TODO: make path to socket configurable!

  -- WARNING: Can't fork beyond this point, since we've stored our pid!
  -- TODO: Install atfork() protection to handle this issue gracefully.
  assert(PID == nil)
  PID = posix.getpid("pid")

  assert(NODE_ID == nil)
  NODE_ID = node_id

  do
    local random_seed = random_seed_from_string(
        NODE_ID .. tostring(PID) .. tostring(os.time())
      )
    math.randomseed(random_seed)
    log("random seed set:", random_seed)
  end

  -- TODO: Take this from internal config instead!
  -- TODO: Check if nodeid is fit for filename. Fail otherwise.
  local zmq_control_socket_filename =
      "/var/run/#{PROJECT_NAME}/#{API_NAME}/control/"
   .. NODE_ID .. "/" .. PID .. ".ipc"

  -- TODO: This should not be needed.
  assert(create_path_to_file(zmq_control_socket_filename))

  ZMQ_CONTROL_SOCKET_URL = "ipc://" .. zmq_control_socket_filename

  run_once(
      request_manager, make_stub_wsapi_env(),
      SERVICE_NAME, NODE_ID, PID
    )

  log("control socket", ZMQ_CONTROL_SOCKET_URL)

  fcgi_wsapi_runner_run(
      run,
      ZMQ_CONTROL_SOCKET_URL,
      system_action_handlers,
      ZMQ_CONTEXT
    )

  log("done")

  ZMQ_CONTEXT:term()
  ZMQ_CONTEXT = nil
end

--------------------------------------------------------------------------------

return
{
  loop = loop;
}
