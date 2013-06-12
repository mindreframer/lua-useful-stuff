--------------------------------------------------------------------------------
-- run.lua: list import()-compliant exports
-- This file is a part of pk-tools library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------

local arguments,
      optional_arguments,
      method_arguments,
      eat_true
      = import 'lua-nucleo/args.lua'
      {
        'arguments',
        'optional_arguments',
        'method_arguments',
        'eat_true'
      }

local is_table
      = import 'lua-nucleo/type.lua'
      {
        'is_table'
      }

local escape_lua_pattern
      = import 'lua-nucleo/string.lua'
      {
        'escape_lua_pattern'
      }

local empty_table,
      timap,
      tkeys,
      tclone
      = import 'lua-nucleo/table.lua'
      {
        'empty_table',
        'timap',
        'tkeys',
        'tclone'
      }

local tpretty
      = import 'lua-nucleo/tpretty.lua'
      {
        'tpretty'
      }

local find_all_files,
      does_file_exist
      = import 'lua-aplicado/filesystem.lua'
      {
        'find_all_files',
        'does_file_exist'
      }

local make_loggers
      = import 'pk-core/log.lua'
      {
        'make_loggers'
      }

local load_tools_cli_data_schema,
      load_tools_cli_config,
      print_tools_cli_config_usage,
      freeform_table_value
      = import 'pk-core/tools_cli_config.lua'
      {
        'load_tools_cli_data_schema',
        'load_tools_cli_config',
        'print_tools_cli_config_usage',
        'freeform_table_value'
      }

local create_config_schema
      = import 'list-exports/project-config/schema.lua'
      {
        'create_config_schema'
      }

--------------------------------------------------------------------------------

local log, dbg, spam, log_error = make_loggers("list-exports", "LEX")

--------------------------------------------------------------------------------

local Q = function(v) return ("%q"):format(tostring(v)) end

--------------------------------------------------------------------------------

local list = function(
    sources_dir,
    root_dir_only,
    profile_filename,
    out_filename,
    lib_name,
    file_header
  )
  -- Remove trailing slashes
  sources_dir = sources_dir:gsub("/+$", "")
  root_dir_only = root_dir_only and root_dir_only:gsub("/+$", "")
  file_header = file_header
    or [[
-- This file is a part of ]], (lib_name or root_dir_only or sources_dir), [[ library
-- See file `COPYRIGHT` for the license and copyright information
]]
  log(
      "listing all exports in ", sources_dir .. "/",
      "using profile", profile_filename,
      "dumping to", out_filename
    )

  if root_dir_only then
    log("only in root directory", root_dir_only) -- TODO: bad name
  end

  local PROFILE = import(profile_filename) ()

  local export_map = setmetatable(
      -- TODO: Check format of PROFILE.raw
      PROFILE.raw and tclone(PROFILE.raw) or { },
      {
        __index = function(t, k)
          local v = { }
          t[k] = v
          return v
        end;
      }
    )

  local files
  local dir = root_dir_only and (sources_dir .. "/" .. root_dir_only) or sources_dir
  if not does_file_exist(dir) then
    -- TODO: Shouldn't we crash here?
    --              sources_dir is cfg:path, not cfg:existing_path though
    log("warning: sources dir does not exist", dir)
    files = { }
  else
    files = find_all_files(
        root_dir_only and (sources_dir .. "/" .. root_dir_only) or sources_dir,
        "%.lua$"
      )

    table.sort(files)
  end

  for i = 1, #files do
    local filename = files[i]
    local listed_filename = filename

    if root_dir_only then
      listed_filename = filename:gsub(
          escape_lua_pattern(sources_dir) .. "/",
          ""
        )
    end

    if PROFILE.skip[listed_filename] then
      log("skipping file", listed_filename)
    else
      log("loading exports from file", filename)
      if root_dir_only then
        log("file would be mentioned as", listed_filename)
      end

      local exports = import (filename) ()
      for name, _ in pairs(exports) do
        local map = export_map[name]
        map[#map + 1] = listed_filename
      end
    end
  end

  local sorted_map = { }
  for export, filenames in pairs(export_map) do
    if #filenames > 1 then
      log("found duplicates for", export, "in", filenames)
    end

    sorted_map[#sorted_map + 1] =
    {
      export = export;
      filenames = filenames;
    }
  end

  table.sort(
      sorted_map,
      function(lhs, rhs)
        return tostring(lhs.export) < tostring(rhs.export)
      end
    )

  do
    local file = assert(io.open(out_filename, "w"))

    file:write([[
--------------------------------------------------------------------------------
-- generated exports map for ]], (root_dir_only or sources_dir), "/", [[

]] .. file_header .. [[
--------------------------------------------------------------------------------
-- WARNING! Do not change manually!
--          Generated by list-exports.
--------------------------------------------------------------------------------

return
{
]])

  for i = 1, #sorted_map do
    local export, filenames = sorted_map[i].export, sorted_map[i].filenames

    file:write([[
  ]], export, [[ = { ]], table.concat(timap(Q, filenames), ", "), [[ };
]])
  end

  file:write([[
}
]])

    file:close()
    file = nil
  end

  log("OK")
end

--------------------------------------------------------------------------------

local SCHEMA = create_config_schema()

local EXTRA_HELP, CONFIG, ARGS

--------------------------------------------------------------------------------

local ACTIONS = { }

ACTIONS.help = function()
  print_tools_cli_config_usage(EXTRA_HELP, SCHEMA)
end

ACTIONS.check_config = function()
  io.stdout:write("config OK\n")
  io.stdout:flush()
end

ACTIONS.dump_config = function()
  io.stdout:write(tpretty(freeform_table_value(CONFIG), " ", 80), "\n")
  io.stdout:flush()
end

ACTIONS.list_all = function()
  local exports = CONFIG.common.exports

  local sources = freeform_table_value(exports.sources) -- Hack. Use iterator
  for i = 1, #sources do
    local source = sources[i]

    list(
        source.sources_dir,
        source.root_dir_only, -- May be nil
        exports.profiles_dir .. source.profile_filename,
        exports.exports_dir .. source.out_filename,
        source.lib_name, -- May be nil
        source.file_header -- May be nil
      )
  end
end

--------------------------------------------------------------------------------

EXTRA_HELP = [[

Usage:

  ]] .. arg[0] .. [[ --root=<PROJECT_PATH> <action> [options]

Actions:

  * ]] .. table.concat(tkeys(ACTIONS), "\n  * ") .. [[

]]

--------------------------------------------------------------------------------

local run = function(...)
  CONFIG, ARGS = assert(load_tools_cli_config(
      function(args)
        return
        {
          PROJECT_PATH = args["--root"];
          list_exports = { action = { name = args[1] or args["--action"]; }; };
        }
      end,
      EXTRA_HELP,
      SCHEMA,
      nil,
      nil,
      ...
    ))
  ACTIONS[CONFIG.list_exports.action.name]()
end

--------------------------------------------------------------------------------

return
{
  run = run;
}
