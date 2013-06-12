--------------------------------------------------------------------------------
-- connector.lua: connecting sockets
-- This file is a part of pk-engine library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------

local socket = require 'socket'
require 'socket.http'

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

local make_loggers
      = import 'pk-core/log.lua'
      {
        'make_loggers'
      }

--------------------------------------------------------------------------------

local log, dbg, spam, log_error = make_loggers("connector", "CTR")

--------------------------------------------------------------------------------

local connect = function(host, port, max_retries, sleep_time)
  max_retries = max_retries or 10 -- TODO: WTF?! Setup defaults for production.
  sleep_time = sleep_time or 0.1

  local conn, err
  for i = 1, max_retries do
    dbg("connecting to ", host, port)

    conn, err = socket.connect(host, port)
    if conn then
      log("connected to ", host, port)
      err = nil
      break
    end

    if i ~= max_retries then
      log("connection to ", host, port, "failed:", err, "retrying")
      dbg("sleeping before retry", i, "of", max_retries)
      socket.sleep(sleep_time)
    end
  end

  if not conn then
    log_error("connection to ", host, port, "failed:", err)
    return nil, err
  end

  return conn
end

local http_request = function(url, max_retries, sleep_time)
  max_retries = max_retries or 10 -- TODO: WTF?! Setup defaults for production.
  sleep_time = sleep_time or 0.1

  local res, err
  for i = 1, max_retries do
    dbg("requesting", url)

    res, err = socket.http.request(url)
    if res then
      err = nil
      break
    end

    if i ~= max_retries then
      log("request of", url, "failed:", err, "retrying")
      dbg("sleeping before retrying request", i, "of", max_retries)
      socket.sleep(sleep_time)
    end
  end

  if not res then
    log_error("request of", url, "failed:", err)
    return nil, err
  end

  return res
end

--------------------------------------------------------------------------------

-- TODO: Why isn't it a function?!
local make_tcp_connector
do
  local connect = function(self)
    method_arguments(
        self
      )

    -- TODO: Make max_retries and sleep_time configurable
    return connect(self.host_, self.port_)
  end

  make_tcp_connector = function(host, port)
    arguments(
        "string", host,
        "number", port
      )

    return
    {
      connect = connect;
      --
      host_ = host;
      port_ = port;
    }
  end
end

--------------------------------------------------------------------------------

local make_domain_socket_connector = function()
  error("TODO: Implement make_domain_socket_connector()")
end

--------------------------------------------------------------------------------

return
{
  connect = connect;
  http_request = http_request;
  make_tcp_connector = make_tcp_connector;
  make_domain_socket_connector = make_domain_socket_connector;
}
