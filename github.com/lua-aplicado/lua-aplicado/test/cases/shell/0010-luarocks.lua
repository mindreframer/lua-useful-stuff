--------------------------------------------------------------------------------
-- 0010-luarocks.lua: tests for shell luarocks library
-- This file is a part of Lua-Aplicado library
-- Copyright (c) Lua-Aplicado authors (see file `COPYRIGHT` for the license)
--------------------------------------------------------------------------------

local pairs
    = pairs

local luarocks_show_rock_dir,
      luarocks_exports
      = import 'lua-aplicado/shell/luarocks.lua'
      {
        'luarocks_show_rock_dir',
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

local starts_with
      = import 'lua-nucleo/string.lua'
      {
        'starts_with'
      }

local test = (...)("luarocks", luarocks_exports)

--------------------------------------------------------------------------------

local INEXISTENT_ROCK_NAME =
    "inexistent-rock-name-6fe29f80-ac87-4421-ac0f-e63da8a22e55"

--------------------------------------------------------------------------------

test:test_for "luarocks_show_rock_dir" (function()
  ensure(
      "lua-nucleo install dir",
       luarocks_show_rock_dir("lua-nucleo"):find("rocks/lua-nucleo", 1, true)
    )
  ensure_fails_with_substring(
      "inexistent rock",
      (function()
          luarocks_show_rock_dir(INEXISTENT_ROCK_NAME)
      end),
      "cannot find package"
    )
end)

--------------------------------------------------------------------------------

-- TODO: https://github.com/lua-aplicado/lua-aplicado/issues/6
-- test with local luarocks repository instead of global one

--------------------------------------------------------------------------------

test:UNTESTED "luarocks_read"
test:UNTESTED "luarocks_exec"
test:UNTESTED "luarocks_exec_no_sudo"
test:UNTESTED "luarocks_exec_dir"
test:UNTESTED "luarocks_admin_exec_dir"
test:UNTESTED "luarocks_remove_forced"
test:UNTESTED "luarocks_ensure_rock_not_installed_forced"
test:UNTESTED "luarocks_make_in"
test:UNTESTED "luarocks_exec_dir_no_sudo"
test:UNTESTED "luarocks_pack_to"
test:UNTESTED "luarocks_admin_make_manifest"
test:UNTESTED "luarocks_load_manifest"
test:UNTESTED "luarocks_get_rocknames_in_manifest"
test:UNTESTED "luarocks_install_from"
test:UNTESTED "luarocks_load_rockspec"
test:UNTESTED "luarocks_list_rockspec_files"
test:UNTESTED "luarocks_parse_installed_rocks"
