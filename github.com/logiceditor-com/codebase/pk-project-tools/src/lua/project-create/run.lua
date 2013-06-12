--------------------------------------------------------------------------------
-- run.lua: project-create runner
-- This file is a part of pk-project-tools library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------

local loadfile, loadstring = loadfile, loadstring

--------------------------------------------------------------------------------

local log, dbg, spam, log_error
      = import 'pk-core/log.lua' { 'make_loggers' } (
          "project-create/run", "PCR"
        )

--------------------------------------------------------------------------------

local table_sort = table.sort

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
      tiflip
      = import 'lua-nucleo/table-utils.lua'
      {
        'tgetpath',
        'tclone',
        'twithdefaults',
        'tset',
        'tiflip'
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

local unify_manifest_dictionary,
      get_template_paths,
      prepare_manifest
      = import 'pk-project-create/common_functions.lua'
      {
        'unify_manifest_dictionary',
        'get_template_paths',
        'prepare_manifest'
      }

local make_project_using_fs_structure,
      create_project_fs_structure
      = import 'pk-project-create/replicate_data.lua'
      {
        'make_project_using_fs_structure',
        'create_project_fs_structure'
      }

local create_template_fs_structure
      = import 'pk-project-create/copy_files.lua'
      {
        'create_template_fs_structure'
      }

--------------------------------------------------------------------------------

local create_config_schema
      = import 'project-create/project-config/schema.lua'
      {
        'create_config_schema'
      }

--------------------------------------------------------------------------------

local TOOL_NAME = "project_create"
local CONFIG, ARGS

--------------------------------------------------------------------------------

local create_project
do
  local load_metamanifest_with_tool_defaults = function(
      metamanifest_path,
      project_path
    )
    arguments(
        "string", metamanifest_path,
        "string", project_path
      )

    local metamanifest_defaults = unify_manifest_dictionary(
        load_project_manifest(
            assert(
                luarocks_show_rock_dir("pk-project-tools.pk-project-create"),
                "pk-project-tools.pk-project-create: rock directory not found"
              ):sub(1, -1)
         .. "/src/lua/project-create/metamanifest",
            "",
            ""
          )
      )

    local metamanifest_project = unify_manifest_dictionary(
        load_project_manifest(metamanifest_path, project_path, "")
      )

    if metamanifest_defaults.version ~= metamanifest_project.version then
      log_error(
          "Wrong metamanifest version:",
          "expected:", metamanifest_defaults.version,
          "got:", metamanifest_project.version
        )
      error("Wrong metamanifest version")
    end

    local metamanifest = prepare_manifest(
        twithdefaults(metamanifest_project, metamanifest_defaults)
      )

    metamanifest.project_path = project_path

    return metamanifest
  end

  create_project = function(
      metamanifest_path,
      project_path,
      root_template_name,
      root_template_paths
    )
    arguments(
        "string", metamanifest_path,
        "string", project_path,
        "string", root_template_name,
        "table", root_template_paths
      )
    log("Project generation started", project_path)

    local metamanifest = load_metamanifest_with_tool_defaults(
        metamanifest_path,
        project_path
      )

    make_project_using_fs_structure(
        create_project_fs_structure(
            create_template_fs_structure(
                get_template_paths(root_template_name, root_template_paths),
                metamanifest
              ),
            metamanifest
          ),
        metamanifest
      )

    log("Project", metamanifest.dictionary.PROJECT_NAME, "generated successfully")
  end
end

--------------------------------------------------------------------------------

-- TODO: remove (NYI) in --debug after #3775
local EXTRA_HELP = [[

pk-project-create: fast project creation tool

Usage:

    pk-project-create <metamanifest_directory_path> <project_root_dir> [<template_dir>] [options]

Options:

    --debug                    Verbose output (NYI)
]]

local CONFIG_SCHEMA = create_config_schema()

--------------------------------------------------------------------------------

local run = function(...)
  -- WARNING: Action-less tool. Take care when copy-pasting.

  CONFIG, ARGS = load_tools_cli_config(
      function(args) -- Parse actions
        local param = { }

        param.metamanifest_path = args[1] or args["--metamanifest_path"]
        param.root_project_path = args[2] or args["--root_project_path"]
        param.root_template_name = args[3] or args["--root_template_name"]
        param.root_template_paths = args["--root_template_paths"]
        param.debug = args["--debug"]
        return
        {
          PROJECT_PATH = args["--root"] or "";
          [TOOL_NAME] = param;
        }
      end,
      EXTRA_HELP,
      CONFIG_SCHEMA,
      luarocks_show_rock_dir("pk-project-tools.pk-project-create")
        .. "/src/lua/project-create/project-config/config.lua",
      nil, -- No secondary config file
      ...
    )

  if CONFIG == nil then
    local err = ARGS

    print_tools_cli_config_usage(EXTRA_HELP, CONFIG_SCHEMA)

    io.stderr:write("Error in tool configuration:\n", err, "\n\n")
    io.stderr:flush()

    os.exit(1)
  end

  ------------------------------------------------------------------------------

  create_project(
      CONFIG[TOOL_NAME].metamanifest_path,
      CONFIG[TOOL_NAME].root_project_path,
      CONFIG[TOOL_NAME].root_template_name,
      freeform_table_value(CONFIG[TOOL_NAME].root_template_paths)
    )
end

return
{
  run = run;
}
