--------------------------------------------------------------------------------
-- persistent_connection.lua: persistent connection
-- This file is a part of pk-engine library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------

local tstr = import 'lua-nucleo/table.lua' { 'tstr' }

local arguments,
      optional_arguments,
      method_arguments
      = import 'lua-nucleo/args.lua'
      {
        'arguments',
        'optional_arguments',
        'method_arguments'
      }

local make_loggers
      = import 'pk-core/log.lua'
      {
        'make_loggers'
      }

--------------------------------------------------------------------------------

local log, dbg, spam, log_error = make_loggers("persistent_connection", "PCO")

--------------------------------------------------------------------------------

-- Creates persistent connection object, with interface as follows:
--
--   send() - Proxies 'send' call to socket,
--            detecting whether socket was closed.
--            If socket was closed next time we use the object,
--            new connection will be created.
--            Error is returned to user as is in any way.
--
--   receive() - Proxies 'send' call to socket,
--            detecting whether socket was closed
--            If socket was closed next time we use the object,
--            new connection will be created.
--            Error is returned to user as is in any way.
--
--   close() - Explicitly closes current connection,
--             so next time we use the object,
--             new connection will be created.
--
-- All other functions are proxied directly to socket.
--
local make_persistent_connection
do
  local connection_was_broken = function(err)
    return err == "closed"
  end

  -- Private method
  local get_connection = function(self)
    method_arguments(
        self
      )

    if not self.conn_proxy_ then
      local err
      self.conn_proxy_, err = self.connector_:connect()

      if not self.conn_proxy_ then
        log_error("connection failed", err)
        return nil, err
      end

      spam("connected")
    end

    return self.conn_proxy_
  end

  -- Private method
  local close_connection = function(self)
    method_arguments(
        self
      )

    if self.conn_proxy_ then
      spam("close")
      self.conn_proxy_:close()
      self.conn_proxy_ = nil
    end
  end

  local send = function(self, data, i, j)
    method_arguments(
        self
      )

    local conn, err = get_connection(self)
    if not conn then
      log_error("get_connection failed:", err)
      return nil, err
    end

    local res, err, last_byte = conn:send(data, i, j)
    if not res then
      log_error("send failed", err)
      if connection_was_broken(err) then
        close_connection(self)
      end
      return nil, err, last_byte
    end

    return res
  end

  local receive = function(self, pattern, prefix)
    method_arguments(
        self
      )

    local conn, err = get_connection(self)
    if not conn then
      log_error("get_connection failed:", err)
      return nil, err
    end

    local res, err, partial_result = conn:receive(pattern, prefix)
    if not res then
      log_error("receive failed", err)
      if connection_was_broken(err) then
        close_connection(self)
      end
      return nil, err, partial_result
    end

    return res
  end

  local close = function(self)
    method_arguments(
        self
      )

    close_connection(self) -- Phoenix's style
  end

  local refresh = function(self)
    method_arguments(
        self
      )

    local conn, err = get_connection(self)
    if not conn then
      log_error("get_connection failed:", err)
      return nil, err
    end

    return true
  end

  local delegated_method = function(name)
    return function(self, ...)
      return assert(
          self.conn_proxy_, "not connected"
        )[name](self.conn_proxy_, ...)
    end
  end

  make_persistent_connection = function(connector)
    arguments(
        "table", connector
      )

    return
    {
      -- TODO: Delegate more methods as needed.
      send = send;
      receive = receive;
      close = close;
      -- Undocumented methods for select()
      getfd = delegated_method("getfd");
      dirty = delegated_method("dirty");

      -- Extra API

      -- Note: can't name connect(), socket already has such function.
      refresh = refresh;
      --
      connector_ = connector;
      conn_proxy_ = nil;
    }
  end
end

--------------------------------------------------------------------------------

return
{
  make_persistent_connection = make_persistent_connection;
}
