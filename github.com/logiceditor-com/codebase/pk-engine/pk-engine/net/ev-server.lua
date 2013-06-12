--------------------------------------------------------------------------------
-- ev-server.lua: tools for running servers with lua-ev
-- This file is a part of pk-engine library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------
--
-- WARNING: Event handlers MUST NOT FAIL! Always use xpcall.
--
--------------------------------------------------------------------------------

local ev = require 'ev'
local socket = require 'socket'

--------------------------------------------------------------------------------

local arguments,
      method_arguments,
      optional_arguments
      = import 'lua-nucleo/args.lua'
      {
        'arguments',
        'method_arguments',
        'optional_arguments'
      }

local resume_inner,
      yield_outer,
      eat_tag
      = import 'lua-nucleo/coro.lua'
      {
        'resume_inner',
        'yield_outer',
        'eat_tag'
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

local log, dbg, spam, log_error = make_loggers("net/ev-server", "EVS")

--------------------------------------------------------------------------------

local ev_protect
do
  local error_handler = function(msg)
    msg = debug.traceback(msg, 2)
    log_error(msg)
    return msg
  end

  ev_protect = function(fn)
    return function(loop, watcher, revents)
      local res = xpcall(
          function()
            return fn(loop, watcher, revents)
          end,
          error_handler
        )
      if not res then
        watcher:stop(loop) -- TODO: ?!?!?! May lead to undesired behavior
      end
    end
  end
end

-- WARNING: Callback function runs inside lua-nucleo/coro nested coroutine.
--          If you need to use nested coroutines, resume them
--          with resume_inner.
-- WARNING: It is highly recommended (but not required)
--          to wrap client connection,
--          that is passed to the callback function,
--          into make_buffered_connection().
local run_ev_server
do
  local handle_connection
  do
    -- TODO: Use unique_object after code is stabilized.
    local RECEIVE_TAG = unique_object()
    local SEND_TAG = unique_object()

    local send = function(self, data, i, j)
      method_arguments(self)

      -- We're explicitly passing self to allow working
      -- with multiple connections from the same coroutine.
      --spam("send")
      return yield_outer(self, SEND_TAG, data, i, j)
    end

    local receive = function(self, pattern, prefix)
      method_arguments(self)

      -- We're explicitly passing self to allow working
      -- with multiple connections from the same coroutine.
      --spam("receive")
      return yield_outer(self, RECEIVE_TAG, pattern, prefix)
    end

    local close = function(self)
      method_arguments(self)

      spam("rw_pumper:close() fd", self.conn_:getfd())

      return self.conn_:close()
    end

    local settimeout = function(self, value, mode)
      method_arguments(self)

      return self.conn_:settimeout(value, mode)
    end

    local getfd = function(self)
      return self.conn_:getfd()
    end

    -- NOTE: We need to pass connection "self" from coroutine yield
    --       to allow handling of multiple connections in on coroutine.
    -- TODO: Rename to something more comprehensible (or redesign)
    local function run_impl(coro_self, ok, conn_self, action_tag, ...)
      -- spam("run_impl: tick")

      if not ok then
        local err = conn_self
        log_error("pump failed:", debug.traceback(coro_self.coro_, err))
        coro_self:close()
        -- TODO: Close conn_self as well?
        return false
      end

      if action_tag == RECEIVE_TAG then
        -- TODO: ?! WTF?
        assert(conn_self.loop_ == coro_self.loop_)
        local loop = coro_self.loop_

        local pattern, prefix = ...

        ev.IO.new(
            function(loop, watcher, revents)
              assert(loop == coro_self.loop_) -- TODO: ?!
              watcher:stop(loop)

              return run_impl(
                  coro_self,
                  eat_tag(
                      coroutine.resume(
                          coro_self.coro_,
                          conn_self.conn_:receive(pattern, prefix)
                        )
                    )
                )
            end,
            conn_self.conn_:getfd(),
            ev.READ
          ):start(loop)

        return true
      elseif action_tag == SEND_TAG then
        -- TODO: ?! WTF?
        assert(conn_self.loop_ == coro_self.loop_)
        local loop = coro_self.loop_

        local data, i, j = ...

        ev.IO.new(
            function(loop, watcher, revents)
              assert(loop == coro_self.loop_) -- TODO: ?!
              watcher:stop(loop)

              return run_impl(
                  coro_self,
                  eat_tag(
                      coroutine.resume(
                          coro_self.coro_,
                          conn_self.conn_:send(data, i, j)
                        )
                    )
                )
            end,
            conn_self.conn_:getfd(),
            ev.WRITE
          ):start(loop)

        return true
      end

      -- TODO: WTF?!
      spam("done handling connection fd", coro_self:getfd())
      coro_self:close()

      return false
    end

    local run = function(self)
      method_arguments(self)

      run_impl(self, eat_tag(coroutine.resume(self.coro_, self)))
    end

    local make_rw_pumper = function(loop, conn, coro)

      return
      {
        send = send;
        receive = receive;
        close = close;
        settimeout = settimeout;
        getfd = getfd;
        --
        run = run;
        --
        loop_ = loop;
        coro_ = coro;
        conn_ = conn;
      }
    end

    handle_connection = function(
        loop,
        conn,
        coro
      )
      arguments(
          "userdata", loop,
          -- "userdata", conn, -- May be table
          "thread", coro
        )

      local rw_pumper = make_rw_pumper(
          loop,
          conn,
          coro
        )

      rw_pumper:run() -- TODO: This should be a standalone function, not method.
    end
  end

  run_ev_server = function(name, host, port, ev_loop, scenario_fn)
    arguments(
        "string", name,
        "string", host,
        "number", port,
        "userdata", ev_loop,
        "function", scenario_fn
      )

    log(name, "listening at", host, port)

    local server = assert(socket.bind(host, port))
    server:settimeout(nil)

    ev.IO.new(
        function(loop, watcher, revents)
          local client = assert(server:accept())

          local peername, peerport = client:getpeername()
          dbg(
              name,
              "connected client", peername, peerport,
              "fd", client:getfd()
            )

          return handle_connection(
              loop,
              client,
              coroutine.create(scenario_fn)
            )
        end,
        server:getfd(),
        ev.READ
      ):start(ev_loop)

    log(name, "starting loop")

    ev_loop:loop()

    log(name, "shutting down")

    server:close()

    log(name, "done")
  end
end

--------------------------------------------------------------------------------

return
{
  ev_protect = ev_protect;
  run_ev_server = run_ev_server;
}
