--------------------------------------------------------------------------------
-- http_server.lua: test-only xavante http server
-- This file is a part of pk-test library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------

local xavante = require 'xavante'
require 'wsapi.xavante'

--------------------------------------------------------------------------------

local arguments
      = import 'lua-nucleo/args.lua'
      {
        'arguments'
      }

local empty_table,
      tserialize
      = import 'lua-nucleo/table.lua'
      {
        'empty_table',
        'tserialize'
      }

--------------------------------------------------------------------------------

local make_wsapi_tcp_server_loop
do
  -- TODO: Generalize with make_http_tcp_server_loop()?
  make_wsapi_tcp_server_loop = function(loader)
    return function(host, port, config_host, config_port)
      -- WARNING: Entire work with Xavante MUST happen inside this function.
      --          Xavante is not designed to be run in a several instances
      --          from the same Lua state. This function is a TCP server
      --          loop, usually being run from a fork, so the above limitation
      --          is bearable.

      config_host = config_host or host
      config_port = config_port or port
      arguments(
          "string", host,
          "number", port,
          "string", config_host,
          "number", config_port
        )

      declare 'cookies' -- Xavante wants to access this global

      local extra_vars =
      {
        PK_CONFIG_HOST = config_host;
        PK_CONFIG_PORT = config_port;
      }

      local rules =
      {
        {
          match = { ".*" };
          with = wsapi.xavante.makeHandler(loader(), nil, "/", "", extra_vars)
        }
      }

      xavante.HTTP
      {
        server = { host = host; port = port };

        defaultHost =
        {
          rules = rules;
        };
      }

      xavante.start()
    end
  end
end

--------------------------------------------------------------------------------

return
{
  make_wsapi_tcp_server_loop = make_wsapi_tcp_server_loop;
}
