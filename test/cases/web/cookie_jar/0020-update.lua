--------------------------------------------------------------------------------
-- 002-update.lua: cookie jar updates well
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

local test = (...)('update', exports)

--------------------------------------------------------------------------------

test:factory('make_cookie_jar', make_cookie_jar)

--------------------------------------------------------------------------------

test 'update-single-set-cookie' (function()

  local c = make_cookie_jar()
  c:update('foo=1')
  ensure_tdeepequals(
      'foo=1: jar has foo cookie',
      c:get_all(),
      {
        { name = 'foo', value = '1' }
      }
    )
  ensure_strequals(
      'foo=1: seriales to "foo=1"',
      c:format_header_for_url(),
      'foo=1'
    )

end)

--------------------------------------------------------------------------------

test 'update-composite-set-cookie' (function()

  local c = make_cookie_jar()
  c:update(', foo=1, bar = 2,    baz=  3,,,')
  ensure_tdeepequals(
      'jar has foo, bar and baz cookies',
      c:get_all(),
      {
        { name = 'foo', value = '1' },
        { name = 'bar', value = '2' },
        { name = 'baz', value = '3' }
      }
    )
  ensure_strequals(
      'serializes to "foo=1; bar=2; baz=3"',
      c:format_header_for_url(),
      'foo=1; bar=2; baz=3'
    )

end)
