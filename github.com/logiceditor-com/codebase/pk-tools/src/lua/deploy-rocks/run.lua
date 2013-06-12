--------------------------------------------------------------------------------
-- run.lua
-- This file is a part of pk-tools library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------

local log, dbg, spam, log_error
      = import 'pk-core/log.lua' { 'make_loggers' } (
          "deploy-rocks-run", "DRR"
        )

--------------------------------------------------------------------------------

local pcall, assert, error, select, next, loadfile, loadstring
    = pcall, assert, error, select, next, loadfile, loadstring
local os_getenv = os.getenv
local io_open = io.open
local lfs = require 'lfs'

--------------------------------------------------------------------------------

local tpretty
      = import 'lua-nucleo/tpretty.lua'
      {
        'tpretty'
      }

local require_and_declare
      = import 'lua-nucleo/require_and_declare.lua'
      {
        'require_and_declare'
      }

local tstr
      = import 'lua-nucleo/tstr.lua'
      {
        'tstr'
      }

local assert_is_table
      = import 'lua-nucleo/typeassert.lua'
      {
        'assert_is_table'
      }

local do_in_environment
      = import 'lua-nucleo/sandbox.lua'
      {
        'do_in_environment'
      }

local timapofrecords,
      twithdefaults,
      tgetpath,
      tclone
      = import 'lua-nucleo/table-utils.lua'
      {
        'timapofrecords',
        'twithdefaults',
        'tgetpath',
        'tclone'
      }

local write_file,
      read_file,
      find_all_files,
      does_file_exist,
      do_atomic_op_with_file
      = import 'lua-aplicado/filesystem.lua'
      {
        'write_file',
        'read_file',
        'find_all_files',
        'does_file_exist',
        'do_atomic_op_with_file'
      }

local load_project_manifest
      = import 'pk-tools/project_manifest.lua'
      {
        'load_project_manifest'
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

local deploy_rocks_from_versions_filename,
      deploy_rocks_from_code
      = import 'deploy-rocks/deploy_rocks.lua'
      {
        'deploy_rocks_from_versions_filename',
        'deploy_rocks_from_code'
      }

local check_manifest
      = import 'deploy-rocks/check_manifest.lua'
      {
        'check_manifest'
      }

local writeln_flush,
      write_flush,
      ask_user,
      load_table_from_file
      = import 'deploy-rocks/common_functions.lua'
      {
        'writeln_flush',
        'write_flush',
        'ask_user',
        'load_table_from_file'
      }

--------------------------------------------------------------------------------

local create_config_schema
      = import 'deploy-rocks/project-config/schema.lua'
      {
        'create_config_schema'
      }

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Config-related constants
--

-- TODO: move to some actual config
local CACHE_PATH = os_getenv("HOME") .. "/.deploy-rocks.cache"
local CACHE_FILE

local TOOL_NAME = "deploy_rocks"

--TODO: insert some description here and clean up
local EXTRA_HELP = [[

deploy-rocks: deployment tool

Usage:

    deploy-rocks <action> <cluster> [<version_file>] [<machine_name>] [options]

Actions:

    deploy_from_code               If 'deploy_from_code' is used <version_file>
                                   and <machine_name> must not be defined.

    deploy_from_versions_file      If 'deploy_from_versions_file' is used
                                   <version_file> must be defined.

    partial_deploy_from_versions_file
                                   If 'partial_deploy_from_versions_file' is
                                   used both <version_file> and <machine_name>
                                   must be defined.

Options:

    --debug                        Allow not clean git repositories

    --dry-run                      Go through algorythm but do nothing

    --local-only                   Deploy will work without external connections
                                   (debug mode included)
                                   Only for test purposes on localhost

Example:

     deploy-rocks deploy_from_code localhost --debug

]]

local CONFIG_SCHEMA = create_config_schema()

local CONFIG, ARGS

local ACTIONS = { }

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Auxiliary actions
--

ACTIONS.help = function()
  print_tools_cli_config_usage(EXTRA_HELP, CONFIG_SCHEMA)
end

ACTIONS.check_config = function()
  write_flush("config OK\n")
end

ACTIONS.dump_config = function()
  write_flush(tpretty(freeform_table_value(CONFIG), "  ", 80), "\n")
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Main deploy actions
--
do
  local common_action = function(handler)
    return function()
      local param = freeform_table_value(CONFIG.deploy_rocks.action.param)

      param.version_filename = param.version_filename or ""
      param.machine_name = param.machine_name or ""
      local messages =
      {
        deploy_from_code =
          "Do you want to deploy code to `" .. param.cluster_name .. "'?";
        deploy_from_versions_file =
          "Do you want to deploy code to `" .. param.cluster_name .. "'"
       .. " from version file `" .. param.version_filename or "" .. "'?";
        partial_deploy_from_versions_file =
          "(Not recommended!) Do you want to deploy code to cluster `"
       .. param.cluster_name .. "' ONE machine `"
       .. param.machine_name .. "' "
       .. "from version file `" .. param.version_filename .. "'?"
       .. " (WARNING: Ensure you pushed changes to cluster's LR repository.)";
      }
      if not param.dry_run then
        if ask_user(
            messages[CONFIG[TOOL_NAME].action.name],
            { "y", "n" },
            "n"
          ) ~= "y"
        then
          error("Aborted.")
        end
      end

      -- check if cachefile exists in CACHE_PATH, load it to cache variable
      assert(does_file_exist(CACHE_PATH))
      local file_string = CACHE_FILE:read("*all")

      local chunk = assert(loadstring(file_string))
      local ok, cache = assert(do_in_environment(chunk, { }))
      assert_is_table(cache)
      writeln_flush("----> Cache file loaded `", CACHE_PATH, "'")

      local manifest = load_project_manifest(
          param.manifest_path,
          CONFIG.PROJECT_PATH,
          param.cluster_name
        )

      manifest.cli_param = param
      manifest.cache = cache

      if param.debug   then writeln_flush("-!!-> DEBUG MODE ON") end
      if param.local_only then writeln_flush("-!!-> LOCAL ONLY MODE ON") end
      if param.dry_run then writeln_flush("-!!-> DRY RUN BEGIN <----") end

      check_manifest(manifest)
      handler(manifest, param)

      -- write cache file
      CACHE_FILE:seek("set")
      assert(
          CACHE_FILE:write("return\n" .. tpretty(manifest.cache, "  ", 80))
        )
      writeln_flush("----> Cache file wrote `", CACHE_PATH, "'")

      if param.dry_run then
        writeln_flush("-!!-> DRY RUN END <----")
      else
        writeln_flush("----> OK")
      end
    end
  end

  ------------------------------------------------------------------------------

  ACTIONS.deploy_from_code = common_action(
      function(
          manifest,
          param
        )
        deploy_rocks_from_code(
            manifest,
            param.cluster_name,
            param.dry_run
         )
      end
    )

  ------------------------------------------------------------------------------

  ACTIONS.deploy_from_versions_file = common_action(
      function(
          manifest,
          param
        )
        deploy_rocks_from_versions_filename(
            manifest,
            param.cluster_name,
            param.version_filename,
            true,
            param.dry_run
          )
      end
    )

  ------------------------------------------------------------------------------

  ACTIONS.partial_deploy_from_versions_file = common_action(
      function(
          manifest,
          param
        )
        -- TODO: HACK
        do
          local clusters_by_name = timapofrecords(manifest.clusters, "name")
          local machines =
            assert(clusters_by_name[param.cluster_name], "cluster not found").machines
          local found = false
          for i = 1, #machines do
            local machine = machines[i]
            if machine.name ~= param.machine_name then
              writeln_flush("----> Ignoring machine `", machine.name, "'")
              machines[i] = nil
            else
              found = true
              writeln_flush("----> Deploying to machine `", machine.name, "'")
            end
          end

          assert(found == true, "machine not found")
        end

        deploy_rocks_from_versions_filename(
            manifest,
            param.cluster_name,
            param.version_filename,
            false,
            param.dry_run
          )
      end
    )

end

--------------------------------------------------------------------------------

-- TODO: AUTOMATE THIRD-PARTY MODULE UPDATES! (when our modules are not changed)
-- TODO: Check out proper branches in each repo before analysis.
-- TODO: Do with lock file
-- TODO: ALSO LOCK REMOTELY!
-- TODO: Handle rock REMOVAL!
local run = function(...)

  if not does_file_exist(CACHE_PATH) then
    assert(
        write_file(CACHE_PATH, "return " .. tpretty({ }, "  ", 80) .. "\n")
      )
    writeln_flush("----> Cache file created `", CACHE_PATH, "'")
  end

  -- Lock cache file
  do_atomic_op_with_file(
      CACHE_PATH,
      function(file, ...)
        local CODE_ROOT = assert(select(1, ...), "code root missing")
        CACHE_FILE = file
        writeln_flush("----> Cache file locked `", CACHE_PATH, "'")
        ------------------------------------------------------------------------
        -- Handle command-line options
        --
        CONFIG, ARGS = assert(load_tools_cli_config(
            function(args) -- Parse actions
              local param = { }

              local action_name   = args[2] or "help"

              param.manifest_path = args[1]
              param.cluster_name  = args[3]
              param.dry_run       = args["--dry-run"]
              param.local_only    = args["--local_only"] or args["--local-only"]
              param.debug         = args["--debug"] or param.local_only

              if action_name     == "deploy_from_versions_file" then
                param.version_filename = args[4]
              elseif action_name == "partial_deploy_from_versions_file" then
                param.version_filename = args[4]
                param.machine_name     = args[5]
              end

              local config =
              {
                PROJECT_PATH = CODE_ROOT;
                [TOOL_NAME] = {
                  action = {
                    name = action_name;
                    param = param;
                  };
                }
              }

              return config
            end,
            EXTRA_HELP,
            CONFIG_SCHEMA,
            nil, -- Specify primary config file with --base-config cli option
            nil, -- No secondary config file
            select(2, ...) -- First argument is CODE_ROOT, eating it
          ))

        ------------------------------------------------------------------------------
        -- Run the action that user requested
        --
        ACTIONS[CONFIG[TOOL_NAME].action.name]()
      end,
      ...
    )
end

--------------------------------------------------------------------------------

return
{
  run = run;
}
