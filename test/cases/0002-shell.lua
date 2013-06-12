--------------------------------------------------------------------------------
-- 0002-shell.lua: tests for shell piping
-- This file is a part of Lua-Aplicado library
-- Copyright (c) Lua-Aplicado authors (see file `COPYRIGHT` for the license)
--------------------------------------------------------------------------------

local pairs
    = pairs

local shell_read,
      shell_read_no_subst,
      shell_write,
      shell_write_no_subst,
      shell_write_async,
      shell_write_async_no_subst,
      shell_exec,
      shell_exec_no_subst,
      shell_escape,
      shell_escape_many,
      shell_escape_no_subst,
      shell_escape_many_no_subst,
      shell_format_command,
      shell_format_command_no_subst,
      shell_wait,
      exports
      = import 'lua-aplicado/shell.lua'
      {
        'shell_read',
        'shell_read_no_subst',
        'shell_write',
        'shell_write_no_subst',
        'shell_write_async',
        'shell_write_async_no_subst',
        'shell_exec',
        'shell_exec_no_subst',
        'shell_escape',
        'shell_escape_many',
        'shell_escape_no_subst',
        'shell_escape_many_no_subst',
        'shell_format_command',
        'shell_format_command_no_subst',
        'shell_wait'
      }

local ensure,
      ensure_equals,
      ensure_strequals,
      ensure_error,
      ensure_fails_with_substring
      = import 'lua-nucleo/ensure.lua'
      {
        'ensure',
        'ensure_equals',
        'ensure_strequals',
        'ensure_error',
        'ensure_fails_with_substring'
      }

local test = (...)("shell", exports)

--------------------------------------------------------------------------------

test:test_for "shell_read" (function()
  ensure_strequals(
      "plain read",
      shell_read("/bin/echo", "foobar foo"),
      "foobar foo\n"
    )
  ensure_equals("empty read", shell_read("/bin/true"), "")
  ensure_fails_with_substring(
      "false read",
      (function()
          shell_read("/bin/false")
      end),
      "command `/bin/false' stopped with rc==1"
    )
end)

--------------------------------------------------------------------------------

-- This case tests only functionality that differs from shell_read
test:test_for "shell_read_no_subst" (function()
  ensure_strequals(
      "plain read",
      shell_read_no_subst("/bin/echo", 'foobar foo'),
      'foobar foo\n'
    )
end)

--------------------------------------------------------------------------------

test:tests_for "shell_write"
test:case "exit_0" (function ()
  shell_write("exit 0\n", "/bin/sh")
end)

-- this test different from "exit 0" by miss newline after command
test:case "closing_handle" (function ()
  shell_write("exit 0", "/bin/sh")
end)

test:case "various_exit_codes" (function ()
  for code = 1, 2 do
    ensure_fails_with_substring(
        "failed rc "..code,
        (function()
          shell_write("exit '" .. code .. "'\n", "/bin/sh")
        end),
        "command `/bin/sh' stopped with rc=="..code
      )
  end
end)

--------------------------------------------------------------------------------

test:test_for "shell_exec" (function ()
  ensure_equals("/bin/true", 0, shell_exec("/bin/true"))
  local rc = shell_exec("/bin/false")
  ensure("/bin/false", rc ~= 0)
end)

--------------------------------------------------------------------------------

-- TODO: generalize tests for shell_escape and shell_escape_no_subst after
-- generalizing the functions
  -- GH#4 -- https://github.com/lua-aplicado/lua-aplicado/issues/4
test:tests_for "shell_escape"

test:case "shell_escape_number" (function ()
  ensure_strequals("shell_escape for a number", shell_escape(42), '42')
end)

test:case "shell_escape_empty_string" (function ()
    ensure_strequals("shell_escape for an empty string", shell_escape(""), "''")
end)

test:case "shell_escape_special" (function ()
  local special_sequences =
  {
    "&&";
    "||";
    "(";
    ")";
    "{";
    "}";
    ">";
    ">>";
    "<";
    "<<"
  }

  for _, v in pairs(special_sequences) do
    ensure_strequals("shell_escape for special sequences", shell_escape(v), v)
  end
end)

test:case "shell_escape_do_not_require_escaping" (function ()
  ensure_strequals(
      "shell_escape for a solid string",
      shell_escape('solid_string'),
      'solid_string'
    )
end)

test:case "shell_escape_requires_escaping" (function ()
  ensure_strequals("shell_escape for the space", shell_escape(' '), '" "')
  ensure_strequals(
      "shell_escape for a string with the space",
      shell_escape('a string with the space'),
      '"a string with the space"'
    )
  ensure_strequals(
      "shell_escape for a string with the quote",
      shell_escape('a string with the "quote" inside'),
      '"a string with the \\"quote\\" inside"'
    )
end)

--------------------------------------------------------------------------------

test:tests_for "shell_escape_no_subst"

test:case "shell_escape_no_subst_number" (function ()
  ensure_strequals(
      "shell_escape_no_subst for a number",
      shell_escape_no_subst(42),
      '42'
    )
end)

test:case "shell_escape_no_subst_empty_string" (function ()
  ensure_strequals(
      "shell_escape_no_subst for an empty string",
      shell_escape_no_subst(""),
      "''"
    )
end)

test:case "shell_escape_no_subst_special" (function ()
  local special_sequences =
  {
    "&&";
    "||";
    "(";
    ")";
    "{";
    "}";
    ">";
    ">>";
    "<";
    "<<"
  }

  for _, v in pairs(special_sequences) do
    ensure_strequals(
        "shell_escape_no_subst for special sequences",
        shell_escape_no_subst(v),
        v
      )
  end
end)

test:case "shell_escape_no_subst_do_not_require_escaping" (function ()
  ensure_strequals(
      "shell_escape_no_subst for a solid string",
      shell_escape_no_subst('solid_string'),
      'solid_string'
    )
end)

test:case "shell_escape_no_subst_requires_escaping" (function ()
  ensure_strequals(
      "shell_escape_no_subst for the space",
      shell_escape_no_subst(" "),
      "' '"
    )
  ensure_strequals(
      "shell_escape_no_subst for a string with the space",
      shell_escape_no_subst("a string with the space"),
      "'a string with the space'"
    )
  ensure_strequals(
      "shell_escape_no_subst for a string with the single quote",
      shell_escape_no_subst("a string with the 'single quote' inside"),
      "'a string with the \\'single quote\\' inside'"
    )
end)

--------------------------------------------------------------------------------

test:test_for "shell_escape_many" (function ()
  local param_1 = 42
  local param_2 = ">>"  -- special sequence
  local param_3 = "solid_string"
  local param_4 = "a string with the space"
  local param_5 = 'a string with the "quote" inside'
  local param_6 = ""

  local res_1, res_2, res_3, res_4, res_5, res_6 =
    shell_escape_many(param_1, param_2, param_3, param_4, param_5, param_6)

  ensure_strequals(
      "shell_escape_many for a number",
      shell_escape(param_1),
      res_1
    )
  ensure_strequals(
      "shell_escape_many for special sequences",
      shell_escape(param_2),
      res_2
    )
  ensure_strequals(
      "shell_escape_many for a solid string",
      shell_escape(param_3),
      res_3
    )
  ensure_strequals(
      "shell_escape_many for a string with the space",
      shell_escape(param_4),
      res_4
    )
  ensure_strequals(
      "shell_escape_many for a string with the quote",
      shell_escape(param_5),
      res_5
    )
  ensure_strequals(
      "shell_escape_many an empty string",
      shell_escape(param_6),
      res_6
    )
end)

--------------------------------------------------------------------------------

test:test_for "shell_escape_many_no_subst" (function ()
  local param_1 = 42
  local param_2 = ">>" -- special sequence
  local param_3 = "solid_string"
  local param_4 = "a string with the space"
  local param_5 = "a string with the 'single quote' inside"
  local param_6 = ""

  local res_1, res_2, res_3, res_4, res_5, res_6 =
    shell_escape_many_no_subst(
        param_1,
        param_2,
        param_3,
        param_4,
        param_5,
        param_6
      )

  ensure_strequals(
      "shell_escape_many for a number",
      shell_escape_no_subst(param_1),
      res_1
    )
  ensure_strequals(
      "shell_escape_many for special sequences",
      shell_escape_no_subst(param_2),
      res_2
    )
  ensure_strequals(
      "shell_escape_many for a solid string",
      shell_escape_no_subst(param_3),
      res_3
    )
  ensure_strequals(
      "shell_escape_many for a string with the space",
      shell_escape_no_subst(param_4),
      res_4
    )
  ensure_strequals(
      "shell_escape_many for a string with the quote",
      shell_escape_no_subst(param_5),
      res_5
    )
  ensure_strequals(
      "shell_escape_many an empty string",
      shell_escape_no_subst(param_6),
      res_6
    )
end)

--------------------------------------------------------------------------------

test:test_for "shell_format_command" (function ()
  local param_1 = 42
  local param_2 = ">>"
  local param_3 = "solid_string"
  local param_4 = "a string with the space"
  local param_5 = 'a string with the "quote" inside'
  local param_6 = ""
  local expected = "42" .. " " .. ">>" .. " " .. "solid_string" .. " "
    .. '"a string with the space"' .. " "
    .. '"a string with the \\"quote\\" inside"' .. " " .. "''"

  ensure_strequals(
      "shell_format_command",
      shell_format_command(param_1, param_2, param_3, param_4, param_5, param_6),
      expected
    )
end)

--------------------------------------------------------------------------------

test:test_for "shell_format_command_no_subst" (function ()
  local param_1 = 42
  local param_2 = ">>"
  local param_3 = "solid_string"
  local param_4 = "a string with the space"
  local param_5 = "a string with the 'single quote' inside"
  local param_6 = ""
  local expected = "42" .. " " .. ">>" .. " " .. "solid_string" .. " "
    .. "'a string with the space'" .. " "
    .. "'a string with the \\'single quote\\' inside'" .. " " .. "''"

  ensure_strequals(
      "shell_format_command",
      shell_format_command_no_subst(
          param_1,
          param_2,
          param_3,
          param_4,
          param_5,
          param_6
        ),
      expected
    )
end)

test:test_for "shell_write_async"

-- Based on real bug scenario: https://redmine-tmp.iphonestudio.ru/issues/1564
-- shell_write_async functionality mostly covered by shell_write tests
test:case "async_write_exit_0" (function()
  local pid = shell_write_async("exit 0\n", "/bin/sh")
  shell_wait(pid, "/bin/sh")
end)

test:test_for "shell_write_async_no_subst"

-- Based on real bug scenario: https://redmine-tmp.iphonestudio.ru/issues/1564
-- shell_write_async_no_subst functionality mostly covered by shell_write tests
test:case "async_write_no_subst_exit_0" (function()
  local pid = shell_write_async_no_subst("exit 0\n", "/bin/sh")
  shell_wait(pid, "/bin/sh")
end)

test:test_for "shell_write_no_subst"

-- Based on real bug scenario: https://redmine-tmp.iphonestudio.ru/issues/1564
-- shell_write_no_subst functionality mostly covered by shell_write tests
test:case "shell_write_no_subst_exit_0" (function()
  shell_write_no_subst("exit 0\n", "/bin/sh")
end)

--------------------------------------------------------------------------------

-- shell_wait is covered by tests shell_read and shell_write
test:UNTESTED "shell_wait"

-- shell_exec_no_subst is covered by shell_exec
test:UNTESTED "shell_exec_no_subst"
