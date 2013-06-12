--------------------------------------------------------------------------------
-- fcgi_wsapi_runner.lua: a better wsapi runner for fcgi
-- This file is a part of pk-engine library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------
-- Provides stop() function.
-- Handles system messages
--------------------------------------------------------------------------------

-- To avoid potential conflicts.
if package.loaded['wsapi.fastcgi'] then
  error("this module is not compatible with wsapi.fastcgi")
end

--------------------------------------------------------------------------------

local log, dbg, spam, log_error
    = import 'pk-core/log.lua' { 'make_loggers' } (
        "pk-engine/fcgi_wsapi_runner", "FWR"
      )

--------------------------------------------------------------------------------

local lfcgi = require 'lfcgi'
assert(lfcgi.finish, "wrong lfcgi/wsapi.fcgi version")

local common = require 'wsapi.common'

local zmq = require 'zmq'
require 'zmq.poller'

local luabins = require 'luabins'

require 'bit'

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

local EAGAIN
      = import 'pk-engine/errno.lua'
      {
        'EAGAIN'
      }

--------------------------------------------------------------------------------

-- TODO: Shouldn't this be done much earlier?
-- TODO: Is this really needed?

io.stdout = lfcgi.stdout
io.stderr = lfcgi.stderr
io.stdin = lfcgi.stdin

--------------------------------------------------------------------------------

local FCGI_STDIN_FD = 0

--------------------------------------------------------------------------------

local RUNNING = false

local stop = function()
  -- Note: if this assert is triggered, make sure that you're actually
  -- did invoke run() below, and not some other one (like wsapi.fcgi.run()).
  assert(RUNNING, "can't stop: not running")
  RUNNING = false

  log("FCGI WSAPI Runner: stopping loop on the next iteration")
end

-- Based on wsapi.fcgi.run()
local handle_wsapi_request = function(app_run)
  --dbg("before lfcgi.accept()")

  --
  -- This WSAPI handler executes in slightly unusual configuration: FastCGI file
  -- descriptor (which is stdin) is shared by several processes all spawned by
  -- multiwatch. Therefore it is not guaranteed that handle_wsapi_request() is
  -- called if stdin has any data to read from, as another process might already
  -- have accepted the connection and read all the data.
  --
  -- On the other hand, handle_wsapi_request should not block, otherwise whole
  -- infrastructure of zmq messages controlling behaviour of processes gets
  -- stuck, as it hangs in FCGI_Accept instead of waiting in zmq_poll.
  --
  -- Hence, we place socket into nonblocking mode and finish the request if we
  -- are getting -EAGAIN.
  --

  local stdin_fd = 0
  local status = posix.fcntl(
      stdin_fd,
      posix.F_SETFL,
      bit.bor(posix.fcntl(stdin_fd, posix.F_GETFL), posix.O_NONBLOCK)
    )

  if status < 0 then
    log_error("FCGI WSAPI Runner: unable to place stdin into non-blocking mode:", status)
    stop()
    return
  end

  status = lfcgi.accept()

  if status == -EAGAIN then
    dbg("FCGI WSAPI Runner: idle iteration, another process has accepted the request already (not an error)")
    -- Not stopping, will wait for the next iteration
    return
  end

  if status < 0 then
    -- Seems to be normal in CGI mode.
    log_error("FCGI WSAPI Runner: lfcgi.accept() returned error:", status)
    stop()
    return
  end

  local getenv
  do
    local headers

    getenv = function(n)
      if n == "headers" then
        if headers then
          return headers
        end

        headers = { }

        local env_vars = lfcgi.environ()
        for i = 1, #env_vars do
          local name, val = env_vars[i]:match("^([^=]+)=(.*)$")
          headers[name] = val
        end

        return headers
      else
        return lfcgi.getenv(n) or os.getenv(n)
      end
    end
  end

  common.run(
      app_run,
      {
        input = lfcgi.stdin;
        output = lfcgi.stdout;
        error = lfcgi.stderr;
        env = getenv;
      }
    )

  lfcgi.finish()
  --dbg("after lfcgi.accept()")
end

local handle_control_message
do
  local impl = function(handlers, ok, command, ...)
    if not ok then
      local err = command
      err = "failed to load control message: " .. err
      log_error(err)
      return nil, err
    end

    local handler = handlers[command]
    if not handler then
      local err = "unknown control message: " .. tostring(command)
      log_error(err)
      return nil, err
    end

    return handler(...)
  end

  handle_control_message = function(handlers, msg)
    return impl(handlers, luabins.load(msg))
  end
end

local run_unsafe = function(
    app_run,
    zmq_control_socket_url,
    system_action_handlers,
    zmq_context
  )
  arguments(
      -- "function|table", app_run,
      "string", zmq_control_socket_url,
      "table", system_action_handlers,
      "userdata", zmq_context
    )

  -- To avoid potential conflicts.
  if package.loaded['wsapi.fastcgi'] then
    error("this module is not compatible with wsapi.fastcgi")
  end

  assert(not RUNNING, "can't run: already running")
  RUNNING = true

  local timeout = -1 -- Block indefinitely

  local in_cgi_mode = lfcgi.iscgi()

  log(
      "FCGI WSAPI Runner: starting loop",
      in_cgi_mode and "in CGI mode" or "in FCGI mode"
    )

  if in_cgi_mode then
    while RUNNING do
      --spam("CGI tick")
      handle_wsapi_request(app_run)
      --spam("/CGI tick")
    end
  else
    -- TODO: Double-check what will happen if control socket will die
    --       (if it can meaningfully die in the middle of the work at all).
    local control_socket = assert(zmq_context:socket(zmq.PULL))
    assert(control_socket:bind(zmq_control_socket_url))

    local poller = assert(zmq.poller(2))

    poller:add(FCGI_STDIN_FD, zmq.POLLIN, function()
      --spam("fcgi request")
      handle_wsapi_request(app_run)
      --spam("/fcgi request")
    end)

    poller:add(control_socket, zmq.POLLIN, function()
      spam("control socket message")
      local msg, err = control_socket:recv()
      if not msg then
        log_error("failed to receive control message:", err)
        return
      end

      local res, err = handle_control_message(system_action_handlers, msg)
      if not res then
        log_error("failed to handle control message", err)
        return
      end

      spam("/control socket message")
    end)

    while RUNNING do
      --spam("FCGI tick")
      poller:poll(timeout)
      --spam("/FCGI tick")
    end

    control_socket:close()
  end

  log("FCGI WSAPI Runner: loop done")
end

local error_handler = function(msg)
  log_error("run failed:", debug.traceback(msg))
  return msg
end

local run = function(
    app_run,
    zmq_control_socket_url,
    system_action_handlers,
    zmq_context
  )
  -- Since stderr is likely to be eaten
  local res, err = xpcall(
      function()
        return run_unsafe(
            app_run,
            zmq_control_socket_url,
            system_action_handlers,
            zmq_context
          )
      end,
      error_handler
    )
  assert(res, err)
end

--------------------------------------------------------------------------------

return
{
  stop = stop;
  run = run;
}
