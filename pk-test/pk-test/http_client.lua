--------------------------------------------------------------------------------
-- http_client.lua: test-only client-side utilities for http
-- This file is a part of pk-test library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------

local socket = require 'socket'
require 'socket.http'
require 'socket.url'

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

local ensure,
      ensure_equals,
      ensure_tequals,
      ensure_tdeepequals,
      ensure_strequals,
      ensure_fails_with_substring,
      ensure_returns,
      ensure_error
      = import 'lua-nucleo/ensure.lua'
      {
        'ensure',
        'ensure_equals',
        'ensure_tequals',
        'ensure_tdeepequals',
        'ensure_strequals',
        'ensure_fails_with_substring',
        'ensure_returns',
        'ensure_error'
      }

local make_concatter = import 'lua-nucleo/string.lua' { 'make_concatter' }

local make_loggers
      = import 'pk-core/log.lua'
      {
        'make_loggers'
      }

--------------------------------------------------------------------------------

local log, dbg, spam, log_error = make_loggers("http_client", "HCL")

--------------------------------------------------------------------------------

-- Note this function intentionally does not prepend "?" to the query
local build_simple_http_query = function(param)
  arguments(
      "table", param
    )

  local cat, concat = make_concatter()

  local first = true
  for k, v in pairs(param) do
    if not first then
      cat "&"
    else
      first = false
    end

    cat (socket.url.escape(assert(tostring(k)))) "=" (socket.url.escape(assert(tostring(v))))
  end

  return concat()
end

local check_post_request = function(url, param, expected_checker)
  arguments(
      "string", url,
      "table",  param,
      "function", expected_checker
    )

  expected_checker(
      ensure(
          "do post query",
          socket.http.request(url, build_simple_http_query(param))
        )
    )
end

local check_post_request_simple = function(url, param, expected)
  arguments(
      "string", url,
      "table",  param,
      "string", expected
    )

  check_post_request(
      url,
      param,
      function(response)
        ensure_strequals(
            "request matches expected",
            response,
            expected
          )
      end
    )
end

--------------------------------------------------------------------------------

return
{
  build_simple_http_query = build_simple_http_query;
  check_post_request = check_post_request;
  check_post_request_simple = check_post_request_simple;
}
