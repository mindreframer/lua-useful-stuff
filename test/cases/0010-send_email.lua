--------------------------------------------------------------------------------
-- 0010-send_email.lua: tests for send_email functions
-- This file is a part of Lua-Aplicado library
-- Copyright (c) Lua-Aplicado authors (see file `COPYRIGHT` for the license)
--------------------------------------------------------------------------------

local ensure_strequals
      = import 'lua-nucleo/ensure.lua'
      {
        'ensure_strequals'
      }

local create_email,
      exports
      = import 'lua-aplicado/shell/send_email.lua'
      {
        'create_email'
      }

--------------------------------------------------------------------------------

local test = (...)("send_email", exports)

--------------------------------------------------------------------------------

test:tests_for "create_email"

test "create_email_standard" (function()

      local from = "from@example.net"
      local to = "to@example.net"
      local cc = "to@example.com"
      local bcc = "to@example.org"
      local subject = "Some subject"
      local body = [[Lorem ipsum dolor sit amet, consectetur adipiscing elit.
    Aenean ac arcu ac purus posuere imperdiet vel id dolor.
]]

      local expected = [[From: from@example.net
To: to@example.net
Cc: to@example.com
Bcc: to@example.org
Subject: Some subject
Content-Type: text/plain; charset=utf-8

Lorem ipsum dolor sit amet, consectetur adipiscing elit.
    Aenean ac arcu ac purus posuere imperdiet vel id dolor.
]]

    ensure_strequals(
        "Checking create_email",
        create_email(from, to, cc, bcc, subject, body),
        expected
      )
end)

test "create_email_cc_table" (function()

      local from = "from@example.net"
      local to = "to@example.net"
      local cc_string = "to_1@example.com, to_2@example.com"
      local cc_table = { "to_1@example.com", "to_2@example.com" }
      local bcc = "to@example.org"
      local subject = "Some subject"
      local body = [[Lorem ipsum dolor sit amet, consectetur adipiscing elit.
    Aenean ac arcu ac purus posuere imperdiet vel id dolor.
]]

    ensure_strequals(
        "Checking two ways of setting cc",
        create_email(from, to, cc_string, bcc, subject, body),
        create_email(from, to, cc_table, bcc, subject, body)
      )
end)

test "create_email_bcc_table" (function()

      local from = "from@example.net"
      local to = "to@example.net"
      local cc = "to@example.com"
      local bcc_string = "to_1@example.org, to_2@example.org"
      local bcc_table = { "to_1@example.org", "to_2@example.org" }
      local subject = "Some subject"
      local body = [[Lorem ipsum dolor sit amet, consectetur adipiscing elit.
    Aenean ac arcu ac purus posuere imperdiet vel id dolor.
]]

    ensure_strequals(
        "Checking two ways of setting bcc",
        create_email(from, to, cc, bcc_string, subject, body),
        create_email(from, to, cc, bcc_table, subject, body)
      )
end)

test:UNTESTED "send_email"
