--------------------------------------------------------------------------------
-- check_manifest.lua
-- This file is a part of pk-tools library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------

local log, dbg, spam, log_error
      = import 'pk-core/log.lua' { 'make_loggers' } (
          "deploy-rocks-check-manifest", "CHM"
        )

--------------------------------------------------------------------------------

local pairs, pcall, assert, error, select, next, loadfile, loadstring
    = pairs, pcall, assert, error, select, next, loadfile, loadstring

local table_concat = table.concat
local os_getenv = os.getenv
local io = io
local os = os

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

local is_table
      = import 'lua-nucleo/type.lua'
      {
        'is_table'
      }

local assert_is_table,
      assert_is_string
      = import 'lua-nucleo/typeassert.lua'
      {
        'assert_is_table',
        'assert_is_string'
      }

local tpretty
      = import 'lua-nucleo/tpretty.lua'
      {
        'tpretty'
      }

local tset,
      timapofrecords,
      twithdefaults,
      tkeys,
      tclone,
      tequals
      = import 'lua-nucleo/table-utils.lua'
      {
        'tset',
        'timapofrecords',
        'twithdefaults',
        'tkeys',
        'tclone',
        'tequals'
      }

local trim
      = import 'lua-nucleo/string.lua'
      {
        'trim'
      }

local write_file,
      read_file,
      find_all_files,
      does_file_exist,
      splitpath,
      get_filename_from_path
      = import 'lua-aplicado/filesystem.lua'
      {
        'write_file',
        'read_file',
        'find_all_files',
        'does_file_exist',
        'splitpath',
        'get_filename_from_path'
      }

local shell_read,
      shell_exec
      = import 'lua-aplicado/shell.lua'
      {
        'shell_read',
        'shell_exec'
      }

local git_format_command,
      git_exec,
      git_read,
      git_get_tracking_branch_name_of_HEAD,
      git_update_index,
      git_is_dirty,
      git_is_directory_dirty,
      git_has_untracked_files,
      git_are_branches_different,
      git_is_file_changed_between_revisions,
      git_add_directory,
      git_commit_with_message,
      git_push_all
      = import 'lua-aplicado/shell/git.lua'
      {
        'git_format_command',
        'git_exec',
        'git_read',
        'git_get_tracking_branch_name_of_HEAD',
        'git_update_index',
        'git_is_dirty',
        'git_is_directory_dirty',
        'git_has_untracked_files',
        'git_are_branches_different',
        'git_is_file_changed_between_revisions',
        'git_add_directory',
        'git_commit_with_message',
        'git_push_all'
      }

local luarocks_get_rocknames_in_manifest,
      luarocks_list_rockspec_files,
      luarocks_load_rockspec
      = import 'lua-aplicado/shell/luarocks.lua'
      {
        'luarocks_get_rocknames_in_manifest',
        'luarocks_list_rockspec_files',
        'luarocks_load_rockspec'
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

local writeln_flush,
      write_flush,
      ask_user,
      load_table_from_file,
      find_rock_files_in_subproject
      = import 'deploy-rocks/common_functions.lua'
      {
        'writeln_flush',
        'write_flush',
        'ask_user',
        'load_table_from_file',
        'find_rock_files_in_subproject'
      }

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
local check_manifest
do
  local debug = false

  local writeln_debug = function( ... )
    if debug then
    --  writeln_flush( ... )
    end
  end

  local create_rocks_list = function(manifest)
    writeln_flush("---> Creating rocks list")
    local all_rocks = { }
    local subprojects = manifest.subprojects
    for i = 1, #subprojects do
      local subproject = subprojects[i]
      local name = subproject.name
      writeln_flush("--> Checking subproject `", name, "'...")

      subproject.local_path = subproject.local_path
        or manifest.project_path .. "/" .. name

      local path = subproject.local_path
      local info = git_read(path, "rev-parse", "--abbrev-ref", "HEAD")
      write_flush("Current branch of ", name, " repository: ", info)
      info = git_read(path, "rev-parse", "HEAD")
      write_flush("HEAD of ", name, " repository: ", info)

      if subproject.no_deploy then
        writeln_flush("--> Skipping no-deploy subproject `", name, "'.")
      else
        writeln_flush("--> Collecting data from `", name, "'...")

        local path = assert(subproject.local_path)

        if subproject.provides_rocks_repo then
          if not is_table(subproject.provides_rocks_repo) then
            subproject.provides_rocks_repo =
              { { name = subproject.provides_rocks_repo } }
          end
          for j = 1, #subproject.provides_rocks_repo do
            local have_changed_rocks_in_repo = false
            local rocks_repo = subproject.provides_rocks_repo[j].name
            writeln_flush("-> Searching for rocks in repo `", rocks_repo, "'...")

            local rock_files, rockspec_files =
              find_rock_files_in_subproject(path, rocks_repo)
            for k = 1, #rock_files do
              if string.find(rock_files[k].filename, ".rockspec") then
                all_rocks[rock_files[k].name] =
                  {
                    rockspec = subproject.local_path .. "/" .. assert(rock_files[k].filename);
                  }
              end
            end
          end
        elseif -- if subproject.provides_rocks_repo then
          subproject.provides_rocks and
          not tequals(subproject.provides_rocks, { })
        then
          local rocks = assert(subproject.provides_rocks)

          if #rocks > 0 then
            -- TODO: move to manifest sanity check?
            if subproject.rockspec_generator then
              if manifest.cli_param.dry_run then
                writeln_flush("-!!-> DRY RUN: Want to generate rockspecs")
              else
                writeln_flush("--> Generating rockspecs...")
                local rockspec_generator = is_table(subproject.rockspec_generator)
                  and subproject.rockspec_generator
                   or { subproject.rockspec_generator }
                assert(
                    shell_exec(
                        "cd", subproject.local_path,
                        "&&", unpack(rockspec_generator)
                      ) == 0
                  )
              end
            end

            for j = 1, #rocks do
              local rock = rocks[j]
              all_rocks[rock.name] =
                {
                  rockspec = subproject.local_path .. "/" .. assert(rock.rockspec);
                }
            end -- for i = 1, #rocks do
          else
            writeln_flush("----> No rocks in subproject...")
          end -- if #rocks > 0 then
        else
          error("Empty subproject without no-deploy mark found: " .. name)
        end
      end -- if subproject.no_deploy else
    end
    writeln_debug("---> all_rocks `", tpretty(all_rocks, "  ", 80), "'...")
    writeln_flush("---> OK, rocks list created")
    return all_rocks
  end

  local check_rockspecs_exist = function(manifest, rocks_list)
    writeln_flush("---> Checking that all rockspecs exist")
    for k, v in pairs(rocks_list) do
      if not does_file_exist(rocks_list[k].rockspec) then
        error(
            "Rockspec " .. rocks_list[k].rockspec
         .. " of " .. k .. " rock doesn't exist.")
      else
        writeln_debug("--> rockspec `", rocks_list[k].rockspec, "' exists")
      end
    end -- for i = 1, #rocks do
    writeln_flush("---> OK, all rockspecs exist")
  end

  local function check_installed_rock(rocks_list, rock, not_used)
    writeln_debug("--> checking rock `", rock, "'")
    if not rocks_list[rock] then
      -- TODO: Hack. Try to find more generic way to handle exceptions
      if rock ~= "lua" then
        writeln_debug(rock, ": rock used in roles, but doesn't exist in subprojects")
        not_used[rock] = true
      end
    elseif not rocks_list[rock].used then
      local rockspec = luarocks_load_rockspec(rocks_list[rock].rockspec)
      rocks_list[rock].used = true
      writeln_debug("--> rockspec: `", rocks_list[rock].rockspec, "' loaded")
      if rockspec.dependencies then
        writeln_debug("--> dependencies: `", tpretty(rockspec.dependencies, "  ", 80), "' used")
        for i = 1, #rockspec.dependencies do
          writeln_debug("-->" , rockspec.dependencies[i])
          local rock_dependency
          if string.find(rockspec.dependencies[i], "=") then
            rock_dependency = string.sub(
                rockspec.dependencies[i],
                1,
                string.find(rockspec.dependencies[i], " ", 1, true) - 1
              )
          else
            rock_dependency = rockspec.dependencies[i]
          end
          writeln_debug("--> dependenci: `", rock_dependency, "' used")
          check_installed_rock(rocks_list, rock_dependency, not_used)
        end
      else
        writeln_debug("--> NO DEPENDANCIES IN ROCKSPEC!: `", rock)
        writeln_debug("--> dependencies: `", tpretty(rockspec, "  ", 80), "' used")
      end
    end
  end

  local check_installed_rocks_list = function(manifest, rocks_list)
    local not_used = { }
    writeln_flush("---> Checking rocks to install match rocks list")
    for i = 1, #manifest.roles do
      for j = 1, #manifest.roles[i].deployment_actions do
        if manifest.roles[i].deployment_actions[j].tool == "deploy_rocks" then
          for k = 1, #manifest.roles[i].deployment_actions[j] do
            local rock = manifest.roles[i].deployment_actions[j][k]
              check_installed_rock(rocks_list, rock, not_used)
          end
        end
      end
    end
    writeln_flush("---> OK, checked if rocks to install match rocks list")
    if tequals(not_used, { }) then
      writeln_flush("----> OK, all rocks in dependencies found in subprojects")
    else
      writeln_flush("----> Rocks found in dependencies but not in subprojects:")
      for k, v in pairs(not_used) do
        writeln_flush("  ", k)
      end
      -- TODO: fix problem with initializing empty repositiories
      -- error("rocks found in dependencies that are not in subprojects")
    end
    writeln_flush("----> Rocks found in subprojects but never met in roles:")
    for k, v in pairs(rocks_list) do
      if rocks_list[k].used then
        rocks_list[k] = nil
      else
        -- TODO: this must cause error after all dependencies will be fixed
        writeln_flush("  ", k)
      end
    end
  end

  check_manifest = function(manifest)
    arguments("table", manifest)
    debug = manifest.cli_param.debug

    writeln_flush("----> Checking manifest sanity...")
    local rocks_list = assert_is_table(create_rocks_list(manifest))
    check_rockspecs_exist(manifest, rocks_list)
    check_installed_rocks_list(manifest, rocks_list)
    writeln_flush("----> Manifest sanity OK")
  end
end

--------------------------------------------------------------------------------

return
{
  check_manifest = check_manifest;
}
