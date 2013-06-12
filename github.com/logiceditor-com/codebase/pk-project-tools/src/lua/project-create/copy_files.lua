--------------------------------------------------------------------------------
-- copy_files.lua: methods of project-create
-- This file is a part of pk-project-tools library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------

local loadfile, loadstring = loadfile, loadstring

--------------------------------------------------------------------------------

local log, dbg, spam, log_error
      = import 'pk-core/log.lua' { 'make_loggers' } (
          "project-create/copy-files", "CPF"
        )

--------------------------------------------------------------------------------

local lfs = require 'lfs'

--------------------------------------------------------------------------------

local arguments,
      optional_arguments,
      method_arguments
      = import 'lua-nucleo/args.lua'
      {
        'arguments',
        'optional_arguments',
        'method_arguments'
      }

local is_table,
      is_function,
      is_string,
      is_number
      = import 'lua-nucleo/type.lua'
      {
        'is_table',
        'is_function',
        'is_string',
        'is_number'
      }

local tgetpath,
      tclone,
      twithdefaults,
      tset,
      tiflip,
      empty_table
      = import 'lua-nucleo/table-utils.lua'
      {
        'tgetpath',
        'tclone',
        'twithdefaults',
        'tset',
        'tiflip',
        'empty_table'
      }

local ordered_pairs
      = import 'lua-nucleo/tdeepequals.lua'
      {
        'ordered_pairs'
      }

local load_all_files,
      write_file,
      read_file,
      find_all_files,
      is_directory,
      does_file_exist,
      write_file,
      read_file,
      create_path_to_file
      = import 'lua-aplicado/filesystem.lua'
      {
        'load_all_files',
        'write_file',
        'read_file',
        'find_all_files',
        'is_directory',
        'does_file_exist',
        'write_file',
        'read_file',
        'create_path_to_file'
      }

local luarocks_show_rock_dir
      = import 'lua-aplicado/shell/luarocks.lua'
      {
        'luarocks_show_rock_dir'
      }

local copy_file_with_flag,
      copy_file,
      remove_file,
      remove_recursively
      = import 'lua-aplicado/shell/filesystem.lua'
      {
        'copy_file_with_flag',
        'copy_file',
        'remove_file',
        'remove_recursively'
      }

local shell_read,
      shell_exec
      = import 'lua-aplicado/shell.lua'
      {
        'shell_read',
        'shell_exec'
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

local load_project_manifest
      = import 'pk-tools/project_manifest.lua'
      {
        'load_project_manifest'
      }

local tpretty
      = import 'lua-nucleo/tpretty.lua'
      {
        'tpretty'
      }

local tstr
      = import 'lua-nucleo/tstr.lua'
      {
        'tstr'
      }

local unify_manifest_dictionary
      = import 'pk-project-create/common_functions.lua'
      {
        'unify_manifest_dictionary'
      }

--------------------------------------------------------------------------------

-- TODO: until manual log level will be available #3775
dbg = function() end
spam = function() end

--------------------------------------------------------------------------------

-- TODO: move to lua-nucleo #3736
local match_prefix_list = function(str, prefixes)
  prefixes = prefixes or empty_table
  arguments(
      "string", str,
      "table", prefixes
    )
  for i = 1, #prefixes do
    local prefix = prefixes[i]
    if prefix == str:sub(0, #prefix) then
      return true
    end
  end
  return false
end

--------------------------------------------------------------------------------

local function create_fs_structure_recursively(
    root_path,
    metamanifest,
    fs_structure,
    path
  )
  fs_structure = fs_structure or
  {
    path = "";
    type = "directory";
    children = { };
    do_not_replace = false;
  }
  path = path or root_path
  arguments(
      "string", path,
      "table", fs_structure,
      "table", metamanifest,
      "string", root_path
    )

  for filename in lfs.dir(path) do
    if filename ~= "." and filename ~= ".." then
      local filepath = path .. "/" .. filename
      local short_path = filepath:sub(#root_path + 2)
      local attr = lfs.attributes(filepath)
      if not attr then
        return error("bad file attributes: " .. filepath)
      end
      dbg("file: " .. short_path)
      if not match_prefix_list(short_path, metamanifest.remove_paths) then
        if not fs_structure.children[filename] then
          fs_structure.children[filename] =
          {
            path = filepath;
            parent = fs_structure;
            type = attr.mode;
            children = { };
            do_not_replace = match_prefix_list(short_path, metamanifest.ignore_paths);
          }
        else
          dbg("Path already found in child template: " .. filepath)
        end
        if attr.mode == "directory" then
          create_fs_structure_recursively(
              root_path,
              metamanifest,
              fs_structure.children[filename],
              filepath
            )
        end
      else
        dbg("Path skipped: " .. filepath)
      end
    end
  end
  return fs_structure
end

--------------------------------------------------------------------------------

local create_template_fs_structure = function(templates, metamanifest)
  arguments(
      "table", templates,
      "table", metamanifest
    )
  local fs_structure =
  {
    path = "";
    type = "directory";
    children = { };
    do_not_replace = false;
  }
  for i = 1, #templates do
    fs_structure = create_fs_structure_recursively(templates[i], metamanifest, fs_structure)
  end
  return fs_structure
end

--------------------------------------------------------------------------------

return
{
  create_template_fs_structure = create_template_fs_structure;
}
