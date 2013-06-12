--------------------------------------------------------------------------------
-- 006-path.lua: path attribute honored
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

local test = (...)('path', exports)

-- HTTP parameters
local HOST = 'example.com'
local URL = 'http://' .. HOST .. '/'

--------------------------------------------------------------------------------

test:factory('make_cookie_jar', make_cookie_jar)

--------------------------------------------------------------------------------

test 'path' (function()

  local c = make_cookie_jar()
  c:update('foo=1;path=/', URL)
  ensure_tdeepequals(
      'path matches',
      c:get_all(),
      {
        { name = 'foo', value = '1', domain = HOST, path = '/' }
      }
    )
  c:update('foo=2;path=/u', URL)
  c:update('foo=3;path=/u/u', URL)
  ensure_tdeepequals(
      'different path creates new cookie',
      c:get_all(),
      {
        {
          name = 'foo',
          value = '1',
          domain = HOST,
          path = '/',
          old_value = '1'
        },
        {
          name = 'foo',
          value = '2',
          domain = HOST,
          path = '/u',
          old_value = '2'
        },
        {
          name = 'foo',
          value = '3',
          domain = HOST,
          path = '/u/u'
        }
      }
    )
  ensure_strequals(
      'path matches',
      c:format_header_for_url(URL),
      'foo=1'
    )
  ensure_strequals(
      'path matches',
      c:format_header_for_url(URL .. 'x'),
      'foo=1'
    )
  ensure_strequals(
      'path matches',
      c:format_header_for_url(URL .. 'x/y'),
      'foo=1'
    )
  ensure_strequals(
      'longer paths go first',
      c:format_header_for_url(URL .. 'u'),
      'foo=2; foo=1'
    )
  ensure_strequals(
      'longer paths go first',
      c:format_header_for_url(URL .. 'u/u'),
      'foo=3; foo=2; foo=1'
    )

end)
