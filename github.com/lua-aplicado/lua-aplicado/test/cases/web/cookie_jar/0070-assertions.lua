--------------------------------------------------------------------------------
-- 007-assertions.lua: cookie assertion helpers work well
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

local test = (...)('assertions', exports)

--------------------------------------------------------------------------------

test:factory('make_cookie_jar', make_cookie_jar)

--------------------------------------------------------------------------------

test 'assertion-helpers' (function()

  local c = make_cookie_jar()

  c:update('foo=1,bar=2')
  ensure_tdeepequals(
      'after update of empty jar with cookies "foo" and "bar"',
      c:get_all(),
      {
        { name = 'foo', value = '1' },
        { name = 'bar', value = '2' }
      }
    )
  ensure_equals('cookie "foo" is set', c:is_set('foo'), true)
  ensure_equals('cookie "bar" is set', c:is_set('bar'), true)
  ensure_equals('cookie "foo" is not updated', c:is_updated('foo'), false)
  ensure_equals('cookie "bar" is not updated', c:is_updated('bar'), false)
  ensure_equals('cookie "foo" is not same', c:is_same('foo'), false)
  ensure_equals('cookie "bar" is not same', c:is_same('bar'), false)

  c:update('foo=2')
  ensure_tdeepequals(
      'after update of cookie "foo" with different value',
      c:get_all(),
      {
        { name = 'foo', value = '2', old_value = '1' },
        { name = 'bar', value = '2', old_value = '2' }
      }
    )
  ensure_equals('cookie "foo" is not set', c:is_set('foo'), false)
  ensure_equals('cookie "bar" is not set', c:is_set('bar'), false)
  ensure_equals('cookie "foo" is updated', c:is_updated('foo'), true)
  ensure_equals('cookie "bar" is not updated', c:is_updated('bar'), false)
  ensure_equals('cookie "foo" is not same', c:is_same('foo'), false)
  ensure_equals('cookie "bar" is same', c:is_same('bar'), true)

  c:update('bar=2')
  ensure_tdeepequals(
      'after update of cookie "bar" with same value',
      c:get_all(),
      {
        { name = 'foo', value = '2', old_value = '2' },
        { name = 'bar', value = '2', old_value = '2' }
      }
    )
  ensure_equals('cookie "foo" is not set', c:is_set('foo'), false)
  ensure_equals('cookie "bar" is not set', c:is_set('bar'), false)
  ensure_equals('cookie "foo" is not updated', c:is_updated('foo'), false)
  ensure_equals('cookie "bar" is not updated', c:is_updated('bar'), false)
  ensure_equals('cookie "foo" is same', c:is_same('foo'), true)
  ensure_equals('cookie "bar" is same', c:is_same('bar'), true)

end)
