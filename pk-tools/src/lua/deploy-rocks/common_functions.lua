--------------------------------------------------------------------------------
-- common_functions.lua
-- This file is a part of pk-tools library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------

local log, dbg, spam, log_error
      = import 'pk-core/log.lua' { 'make_loggers' } (
          "deploy-rocks-common", "DRC"
        )

--------------------------------------------------------------------------------

local pairs, pcall, assert, error, select, next, loadfile, loadstring
    = pairs, pcall, assert, error, select, next, loadfile, loadstring

local table_concat = table.concat
local io = io
local os = os

--------------------------------------------------------------------------------

local arguments
      = import 'lua-nucleo/args.lua'
      {
        'arguments'
      }

local is_table
      = import 'lua-nucleo/type.lua'
      {
        'is_table'
      }

local assert_is_table
      = import 'lua-nucleo/typeassert.lua'
      {
        'assert_is_table'
      }

local tset
      = import 'lua-nucleo/table-utils.lua'
      {
        'tset'
      }

local do_in_environment
      = import 'lua-nucleo/sandbox.lua'
      {
        'do_in_environment'
      }

local copy_file_to_dir,
      remove_file,
      create_symlink_from_to
      = import 'lua-aplicado/shell/filesystem.lua'
      {
        'copy_file_to_dir',
        'remove_file',
        'create_symlink_from_to'
      }

local luarocks_load_manifest
      = import 'lua-aplicado/shell/luarocks.lua'
      {
        'luarocks_load_manifest'
      }

--------------------------------------------------------------------------------
-- TODO: Move these somewhere to lua-aplicado?

local write_flush = function(...)
  io.stdout:write(...)
  io.stdout:flush()
  return io.stdout
end

local writeln_flush = function(...)
  io.stdout:write(...)
  io.stdout:write("\n")
  io.stdout:flush()
  return io.stdout
end

local ask_user = function(prompt, choices, default)
  arguments(
      "string", prompt,
      "table", choices
    )
  assert(#choices > 0)

  local choices_set = tset(choices)

  writeln_flush(
      prompt, " [", table_concat(choices, ","), "]",
      default and ("=" .. default) or ""
    )

  for line in io.lines() do
    if (default and line == "") then
      return default
    end

    if choices_set[line] then
      return line
    end

    writeln_flush(
        prompt, " [", table_concat(choices, ","), "]",
        default and ("=" .. default) or ""
      )
  end

  return default -- May be nil if no default and user pressed ^D
end

-- TODO: Move these somewhere to lua-nucleo?

local load_table_from_file = function(path)
  local chunk = assert(loadfile(path))
  local ok, table_from_file = assert(do_in_environment(chunk, { }))
  assert_is_table(table_from_file)
  return table_from_file
end

--------------------------------------------------------------------------------

local find_rock_files_in_subproject = function(path, rocks_repo)
  local rocks = assert(luarocks_load_manifest(
      path .. "/" .. rocks_repo .. "/manifest"
    ).repository)

  -- TODO: Generalize
  local rock_files, rockspec_files = { }, { }
  for rock_name, versions in pairs(rocks) do
    local have_version = false
    for version_name, infos in pairs(versions) do
      assert(have_version == false, "duplicate rock " .. rock_name
        .. " versions " .. version_name .. " in manifest")
      have_version = true
      for i = 1, #infos do
        local info = infos[i]
        local arch = assert(info.arch)

        local filename = rock_name .. "-" .. version_name .. "." .. arch
        if arch ~= "rockspec" then
          filename = filename .. ".rock"
        end

        filename = rocks_repo .. "/" .. filename;

        if arch == "rockspec" then
          rockspec_files[rock_name] = filename
        end

        writeln_flush("Found `", rock_name, "' at `", filename, "'")

        rock_files[#rock_files + 1] =
        {
          name = rock_name;
          filename = filename;
        }
      end
    end
    assert(have_version == true, "bad rock manifest")
  end
  local tpretty = import 'lua-nucleo/tpretty.lua' { 'tpretty' }
  return rock_files, rockspec_files
end

--------------------------------------------------------------------------------

return
{
  writeln_flush = writeln_flush;
  write_flush = write_flush;
  ask_user = ask_user;
  load_table_from_file = load_table_from_file;
  find_rock_files_in_subproject = find_rock_files_in_subproject;
}
