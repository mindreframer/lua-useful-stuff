--------------------------------------------------------------------------------
-- http_server.lua: test-only xavante http server
-- This file is a part of pk-test library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------

local xavante = require 'xavante'

--------------------------------------------------------------------------------

local arguments
      = import 'lua-nucleo/args.lua'
      {
        'arguments'
      }

local empty_table
      = import 'lua-nucleo/table.lua'
      {
        'empty_table'
      }

--------------------------------------------------------------------------------

-- TODO: Support non-static pages.
-- TODO: Support WSAPI pages via standard WSAPI-Xavante interface.
local make_http_tcp_server_loop
do
  local make_url_responder = function(url, headers, body)
    arguments(
        "string", url,
        "table", headers,
        "string", body
      )

    return function(req, res)
      res.headers = headers -- TODO: tclone?
      res:send_headers()
      res:send_data(body)
    end
  end

  make_http_tcp_server_loop = function(url_list)
    return function(host, port)
      -- WARNING: Entire work with Xavante MUST happen inside this function.
      --          Xavante is not designed to be run in a several instances
      --          from the same Lua state. This function is a TCP server
      --          loop, usually being run from a fork, so the above limitation
      --          is bearable.

      declare 'cookies' -- Xavante wants to access this global

      local rules = { }
      for url, url_info in pairs(url_list) do
        rules[#rules + 1] =
        {
          match = url;
          with = make_url_responder(
              url,
              url_info.headers or empty_table,
              url_info[1]
            );
        }
      end

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
  make_http_tcp_server_loop = make_http_tcp_server_loop;
}
