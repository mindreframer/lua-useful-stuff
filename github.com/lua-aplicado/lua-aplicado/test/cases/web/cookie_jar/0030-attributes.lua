--------------------------------------------------------------------------------
-- 003-attributes.lua: cookie attributes parsed well
-- This file is a part of lua-aplicado library
-- Copyright (c) lua-nucleo authors (see file `COPYRIGHT` for the license)
--------------------------------------------------------------------------------

local ensure,
      ensure_equals,
      ensure_strequals,
      ensure_tdeepequals
      = import 'lua-nucleo/ensure.lua'
      {
        'ensure',
        'ensure_equals',
        'ensure_strequals',
        'ensure_tdeepequals'
      }

local make_cookie_jar,
      exports
      = import 'lua-aplicado/web/cookie_jar.lua'
      {
        'make_cookie_jar'
      }

--------------------------------------------------------------------------------

local test = (...)('attributes', exports)

-- assume local timezone is GMT+04
local GMT_OFFSET = 4

-- HTTP parameters
local DOMAIN = 'example.com'
local HOST = 'foo.' .. DOMAIN .. ':8080'
local URL = 'https://' .. HOST .. '/'

--------------------------------------------------------------------------------

test:factory('make_cookie_jar', make_cookie_jar)

--------------------------------------------------------------------------------

test 'attributes' (function()

  local c = make_cookie_jar()
  c:update(
[[
, foo=1;expires=Mon, 2032-01-01 00:00:00 GMT+00;path= /;domain=.]] .. HOST .. [[,
 bar = 2;Expires = Wed, 2013-07-23 01:02:03 GMT+00;max-AGE=100   ;secure ;HTTPonlY;domain=;path=-,
   baz=  3;httpONLy ;exPireS= Sun, Feb 28 10:18:00 2020 GMT+04,,,
]], URL .. 'a'
    )
  ensure_tdeepequals(
      'multiple cookie attributes parsed well',
      c:get_all(),
      {
        {
          name = 'foo',
          value = '1',
          domain = HOST,
          path = '/',
          expires = 1956528000 - 3600 * GMT_OFFSET
        },
        {
          name = 'bar',
          value = '2',
          domain = HOST,
          path = '-',
          secure = true,
          httponly = true,
          expires = c.time_fn_() + 100
        },
        {
          name = 'baz',
          value = '3',
          domain = HOST,
          path = '/',
          httponly = true,
          expires = 1582870680
        }
      }
    )
  ensure_strequals('honor url', c:format_header_for_url(), '')
  ensure_strequals(
      'stringify well',
      c:format_header_for_url(URL),
      'foo=1; baz=3'
    )
  ensure_strequals(
      'honor httponly',
      c:format_header_for_url(URL, true),
      'foo=1'
    )
  ensure_strequals(
      'honor secure',
      c:format_header_for_url(URL),
      'foo=1; baz=3'
    )

end)
