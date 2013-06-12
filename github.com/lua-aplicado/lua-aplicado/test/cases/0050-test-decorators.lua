--------------------------------------------------------------------------------
-- test/cases/0050-decorators.lua: tests for decorators
-- This file is a part of lua-aplicado library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------

local make_loggers
      = import 'lua-aplicado/log.lua'
      {
        'make_loggers'
      }

local log, dbg, spam, log_error = make_loggers(
    "test/cases/0050-decorators",
    "T050"
  )

--------------------------------------------------------------------------------

local tclone,
      tkeys,
      tisempty
      = import 'lua-nucleo/table-utils.lua'
      {
        'tclone',
        'tkeys',
        'tisempty'
      }

local ensure,
      ensure_equals,
      ensure_tequals,
      ensure_is,
      ensure_returns,
      ensure_has_substring
      = import 'lua-nucleo/ensure.lua'
      {
        'ensure',
        'ensure_equals',
        'ensure_tequals',
        'ensure_is',
        'ensure_returns',
        'ensure_has_substring'
      }

local write_file,
      does_file_exist,
      join_path
      = import "lua-aplicado/filesystem.lua"
      {
        'write_file',
        'does_file_exist',
        'join_path'
      }

local temporary_directory,
      temporary_package_path,
      decorators_exports
      = import 'lua-aplicado/testing/decorators.lua'
      {
        'temporary_directory',
        'temporary_package_path'
      }

--------------------------------------------------------------------------------

local test = (...)("decorators", decorators_exports)

test:group "temporary_directory"

test:case "temporary_directory_cleanup" (function(env)
  local original_test_env =
  {
    test = 42;
  }

  local test_env = tclone(original_test_env)

  local tmpdir
  local good_fake_test = function(test_env)
    ensure_equals("test_env is not mangled", test_env.test, 42)

    -- create a content in tmpdir
    write_file(join_path(test_env.test_tmpdir, "testfile"), "content")

    -- store value out-of-scope, so later we can ensure that it is cleaned up
    tmpdir = test_env.test_tmpdir
  end

  local decorator = temporary_directory("test_tmpdir", "lua-aplicado-test")
  ensure_is("decorator is function", decorator, "function")

  local wrapped = decorator(good_fake_test)
  ensure_is("decorated test is function", decorator, "function")

  wrapped(test_env)

  ensure("fake test was called and tmpdir is set", tmpdir)
  ensure("temporary directory was removed", not does_file_exist(tmpdir))
  ensure_tequals(
      "test environment was not modified",
      test_env,
      original_test_env
    )
end)

test:case "temporary_directory_test_environment" (function(env)
  local test_env = { }
  local called = false
  local good_fake_test = function(test_env)
    called=true
    ensure_returns(
        "only one variable added to test_env",
        1, { { "test_tmpdir" } },
        tkeys(test_env)
    )
  end

  local decorator = temporary_directory("test_tmpdir", "lua-aplicado-test")
  ensure_is("decorator is function", decorator, "function")

  local wrapped = decorator(good_fake_test)
  ensure_is("decorated test is function", decorator, "function")

  wrapped(test_env)
  ensure("good_fake_test called", called)
  ensure("test_env still empty after decorated test", tisempty(test_env))
end)

--------------------------------------------------------------------------------

--TODO: Rewrite tests using check_decorator (#1380)
test:group "temporary_package_path"

test:case "temporary_package_path_works"
  :with(temporary_directory('test_tmpdir', "lua_aplicado_0050_")) (function(test_env)

  -- create a test file to import in tmpdir
  local content = 'return { TEST_CONST = 42 }'

  write_file(join_path(test_env.test_tmpdir, "test_file.lua"), content)

  local called_ok = false
  local good_fake_test = function()
    local const = import "test_file.lua" { 'TEST_CONST' }
    ensure_equals("test_const was imported", const, 42)
    called_ok = true
  end

  local decorator = temporary_package_path('test_tmpdir')
  ensure_is("decorator is function", decorator, "function")

  local wrapped = decorator(good_fake_test)
  ensure_is("decorated test is function", decorator, "function")

  wrapped(test_env)
  ensure("good_fake_test was called", called_ok)
end)

test:case "temporary_package_path_cleanup"
    :with(temporary_directory('test_tmpdir', "lua_aplicado_0050_")) (function(test_env)

  local called_ok = false
  local good_fake_test = function()
    ensure_has_substring("temp package path was added", package.path, test_env.test_tmpdir)
    called_ok = true
  end

  local decorator = temporary_package_path('test_tmpdir')
  ensure_is("decorator is function", decorator, "function")

  local wrapped = decorator(good_fake_test)
  ensure_is("decorated test is function", decorator, "function")

  wrapped(test_env)
  ensure("good_fake_test was called", called_ok)
  ensure(
      "package path was cleaned",
      not package.path:find(test_env.test_tmpdir, nil, true)
    )
end)

--------------------------------------------------------------------------------
