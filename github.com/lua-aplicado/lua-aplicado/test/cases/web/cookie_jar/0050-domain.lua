--------------------------------------------------------------------------------
-- 005-domain.lua: domain attribute honored well
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

local test = (...)('domain', exports)

--------------------------------------------------------------------------------

test:factory('make_cookie_jar', make_cookie_jar)

--------------------------------------------------------------------------------

test 'domain attribute' (function()

  local c = make_cookie_jar()

  -- domain attribute doesn't match request URL
  c:update(
[[
, foo=1;expires=Mon, 2013 ;path= /;domain=a.b.c,
 bar = 2;expires = 2013 1:2:3 GMT;max-AGE=0   ;secure ;HTTPonlY;domain=a.q.w.e;path=-,
   baz=  3;;domain=.e:8080;httpONLy ;expires=,,,
]], 'https://q.w.e:8080/a/b'
    )
  ensure_tdeepequals(
      'mismatch in domain invalidates cookies',
      c:get_all(),
      { }
    )

  -- domain attribute looks like dot-decimal IPv4
  c:update('foo=1;domain=1.2.3.4', 'http://2.3.4/')
  ensure_tdeepequals('domain-match rejects IPv4', c:get_all(), { })

  -- domain attribute looks like IP, but literally equal to host
  c:update('foo=1;domain=1.2.3.4', 'http://1.2.3.4/')
  ensure_tdeepequals(
      'domain-match allows exact match of IPv4',
      c:get_all(),
      {
        { value = '1', path = '/', name = 'foo', domain = '1.2.3.4' }
      }
    )

end)

test 'setting parent domain' (function()

  local c = make_cookie_jar()

  c:update(
      "foo1=1;domain=example.com, foo2=1;domain=.example.com",
      'http://sub.example.com'
    )
  ensure_tdeepequals(
      "it's ok to set cookie for parent domain",
      c:get_all(),
      {
        { domain="example.com", path="/", name="foo1", value="1" };
        { domain="example.com", path="/", name="foo2", value="1" };
      }
    )
end)

test 'setting sub-domain' (function()

  local c = make_cookie_jar()

  c:update("foo=1;domain=sub.example.com", 'http://example.com')
  ensure_tdeepequals(
      "it's not ok to set cookie for sub-domain",
      c:get_all(),
      { }
    )
end)
