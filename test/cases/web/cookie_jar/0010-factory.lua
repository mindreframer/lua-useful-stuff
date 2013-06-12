--------------------------------------------------------------------------------
-- 001-factory.lua: cookie jar factory is sane
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

local assert_is_function
      = import 'lua-nucleo/typeassert.lua'
      {
        'assert_is_function'
      }

local make_cookie_jar,
      exports
      = import 'lua-aplicado/web/cookie_jar.lua'
      {
        'make_cookie_jar'
      }

--------------------------------------------------------------------------------

local test = (...)('factory', exports)

--------------------------------------------------------------------------------

test:factory('make_cookie_jar', make_cookie_jar)

--------------------------------------------------------------------------------

test 'factory-sane' (function()

  local c = make_cookie_jar()
  ensure('has get_all method', assert_is_function(c.get_all))
  ensure('has update method', assert_is_function(c.update))
  ensure(
      'has format_header_for_url method',
      assert_is_function(c.format_header_for_url)
    )
  ensure_tdeepequals('jar is initially empty', c:get_all(), { })
  ensure_strequals(
      'empty jar serializes to empty string',
      c:format_header_for_url(),
      ''
    )

end)

--------------------------------------------------------------------------------

test 'factory-parameters' (function()

  local c = make_cookie_jar()
  ensure_equals('default time function is os.time', c.time_fn_, os.time)

  local t = { } -- N.B. test reference equality
  c = make_cookie_jar(function()
    return t
  end)
  ensure_equals('custom time function surely works', c.time_fn_(), t)

end)
