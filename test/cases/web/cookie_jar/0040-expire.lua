--------------------------------------------------------------------------------
-- 004-expire.lua: cookies expire well
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

local test = (...)('expire', exports)

--------------------------------------------------------------------------------

test:factory('make_cookie_jar', make_cookie_jar)

--------------------------------------------------------------------------------

test 'expire' (function()

  local time = 10

  -- N.B. we use custom time function to freely operate on unix time
  local c = make_cookie_jar(function()
    return time
  end)
  c:update(
[[
, foo=1;expires=mon, 1970 ;path= /;domain=another.other.example.com:8081,
 bar = 2;expires =  1:2:3 GMT;max-AGE=0   ;secure ;HTTPonlY;domain=another.other.example.com:8081;path=-,
   baz=  3;;;;max-aGe=-2;domain=another.other.example.com:8081;httpONLy ;,,,
]], 'https://another.example.com:8081/a/b'
    )
  ensure_tdeepequals('expired cookies do not enter jar', c:get_all(), { })

  -- insert valid expiring cookie with max-age=100
  c:update('foo=1;max-age=100,bar=2')
  ensure_tdeepequals(
      'max-age > 0 honored',
      c:get_all(),
      {
        { name = 'foo', value = '1', expires = time + 100 },
        { name = 'bar', value = '2' }
      }
    )
  ensure_strequals(
      'max-age cookie is living',
      c:format_header_for_url(),
      'foo=1; bar=2'
    )

  -- fast-forward
  time = time + 100
  -- cookie is expired
  ensure_tdeepequals(
      'cookie is ripped, jar is empty',
      c:get_all(),
      {
        { name = 'bar', value = '2' }
      }
    )
  ensure_strequals(
      'max-age cookie is ripped after its TTL',
      c:format_header_for_url(),
      'bar=2'
    )

end)
