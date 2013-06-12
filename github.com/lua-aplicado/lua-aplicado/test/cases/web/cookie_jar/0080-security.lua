--------------------------------------------------------------------------------
-- 008-security.lua: cookies jar honors httponly and secure
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

local test = (...)('security', exports)

-- HTTP parameters
local HOST = 'example.com'
local SECURE_URL = 'https://' .. HOST .. '/'
local URL = 'http://' .. HOST .. '/'

--------------------------------------------------------------------------------

test:factory('make_cookie_jar', make_cookie_jar)

--------------------------------------------------------------------------------

test 'secure' (function()

  local c = make_cookie_jar()
  c:update(', vanilla=1,secure=2;secure,httponly=3;httponly,,,', SECURE_URL)
  ensure_tdeepequals(
      'cookies enter jar',
      c:get_all(),
      {
        {
          name = 'vanilla';
          value = '1';
          domain = HOST;
          path = '/';
        },
        {
          name = 'secure';
          value = '2';
          domain = HOST;
          path = '/';
          secure = true;
        },
        {
          name = 'httponly';
          value = '3';
          domain = HOST;
          path = '/';
          httponly = true;
        }
      }
    )

  ensure_strequals(
      'all cookies reported for secure URL',
      c:format_header_for_url(SECURE_URL),
      'vanilla=1; secure=2; httponly=3'
    )

  ensure_strequals(
      'secure cookies are not reported for insecure URL',
      c:format_header_for_url(URL),
      'vanilla=1; httponly=3'
    )

end)

--------------------------------------------------------------------------------

test 'httponly' (function()

  local c = make_cookie_jar()
  c:update(', vanilla=1,secure=2;secure,httponly=3;httponly,,,', SECURE_URL)

  ensure_strequals(
      'all cookies reported for HTTP access',
      c:format_header_for_url(SECURE_URL),
      'vanilla=1; secure=2; httponly=3'
    )

  ensure_strequals(
      'httponly cookies are not reported for non-HTTP access',
      c:format_header_for_url(SECURE_URL, true),
      'vanilla=1; secure=2'
    )

end)
