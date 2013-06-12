--------------------------------------------------------------------------------
-- run_pre_deploy_actions.lua
-- This file is a part of pk-tools library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------

local log, dbg, spam, log_error
      = import 'pk-core/log.lua' { 'make_loggers' } (
          "deploy-rocks", "DRO"
        )

--------------------------------------------------------------------------------

local pairs, pcall, assert, error, select, next, loadfile, loadstring
    = pairs, pcall, assert, error, select, next, loadfile, loadstring

local table_concat = table.concat
local os_getenv = os.getenv
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

local tstr
      = import 'lua-nucleo/tstr.lua'
      {
        'tstr'
      }

local tset,
      timapofrecords,
      twithdefaults,
      tkeys,
      tclone
      = import 'lua-nucleo/table-utils.lua'
      {
        'tset',
        'timapofrecords',
        'twithdefaults',
        'tkeys',
        'tclone'
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

local shell_exec
      = import 'lua-aplicado/shell.lua'
      {
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

local luarocks_exec,
      luarocks_exec_no_sudo,
      luarocks_exec_dir,
      luarocks_admin_exec_dir,
      luarocks_remove_forced,
      luarocks_ensure_rock_not_installed_forced,
      luarocks_make_in,
      luarocks_exec_dir_no_sudo,
      luarocks_pack_to,
      luarocks_admin_make_manifest,
      luarocks_load_manifest,
      luarocks_get_rocknames_in_manifest,
      luarocks_install_from,
      luarocks_parse_installed_rocks,
      luarocks_load_rockspec,
      luarocks_list_rockspec_files
      = import 'lua-aplicado/shell/luarocks.lua'
      {
        'luarocks_exec',
        'luarocks_exec_no_sudo',
        'luarocks_exec_dir',
        'luarocks_admin_exec_dir',
        'luarocks_remove_forced',
        'luarocks_ensure_rock_not_installed_forced',
        'luarocks_make_in',
        'luarocks_exec_dir_no_sudo',
        'luarocks_pack_to',
        'luarocks_admin_make_manifest',
        'luarocks_load_manifest',
        'luarocks_get_rocknames_in_manifest',
        'luarocks_install_from',
        'luarocks_parse_installed_rocks',
        'luarocks_load_rockspec',
        'luarocks_list_rockspec_files'
      }

local remote_luarocks_remove_forced,
      remote_luarocks_ensure_rock_not_installed_forced,
      remote_luarocks_install_from,
      remote_luarocks_list_installed_rocks
      = import 'lua-aplicado/shell/remote_luarocks.lua'
      {
        'remote_luarocks_remove_forced',
        'remote_luarocks_ensure_rock_not_installed_forced',
        'remote_luarocks_install_from',
        'remote_luarocks_list_installed_rocks'
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
      load_table_from_file
      = import 'deploy-rocks/common_functions.lua'
      {
        'writeln_flush',
        'write_flush',
        'ask_user',
        'load_table_from_file'
      }

--------------------------------------------------------------------------------

local run_pre_deploy_actions
do
  local handlers = { }

--------------------------------------------------------------------------------

  handlers.add_rocks_from_pk_rocks_manifest = function(
      manifest,
      cluster_info,
      subproject,
      rocks_repo,
      current_versions,
      need_new_versions_for_subprojects,
      dry_run,
      action
    )
    local path = assert(subproject.local_path) .. "/" .. assert(rocks_repo.name)
    local manifest_path = assert(action.manifest)

    writeln_flush("----> Adding rocks from rocks manifest ", manifest_path)

    local manifest_chunk = assert(loadfile(manifest_path)) -- path should be absolute

    -- TODO: Sandbox it?
    local rocks_manifest = manifest_chunk()
    local ROCKS = assert(rocks_manifest.ROCKS)

    -- TODO: Rebuild only if rock's file dependencies is changed

    local have_changed_rocks = false

    for i = 1, #ROCKS do
      local rockspec = ROCKS[i]

      if
        rockspec["x-cluster-name"]
        and (rockspec["x-cluster-name"] ~= cluster_info.name)
      then
        -- TODO: Hack. Redesign workflow instead.
        manifest.ignore_rocks = manifest.ignore_rocks or { }
        local data =
          luarocks_load_rockspec(
              action.local_path .. "/" .. assert(rockspec[1])
            )
        local name = assert(data.package)
        manifest.ignore_rocks[get_filename_from_path(name)] = true

        writeln_flush(
            "----> Skipping cluster-specific rock ", name,
            " (not for our cluster)"
          )
      else
        if rockspec.generator then
          if dry_run then
            writeln_flush("-!!-> DRY RUN: Want to generate rockspecs")
          else
            writeln_flush(
                "--> Generating rockspecs with ",
                tstr(rockspec.generator),
                "..."
              )
            local rockspec_generator = is_table(rockspec.generator)
              and rockspec.generator
               or { rockspec.generator }
            assert(
                shell_exec(
                    "cd", action.local_path,
                    "&&", unpack(rockspec.generator)
                  ) == 0
              )
          end
        end

        local filename = assert(rockspec[1])
        local data = luarocks_load_rockspec(action.local_path .. "/" .. filename)
        local name = assert(data.package)
        action.source_repo_name = action.source_repo_name or subproject.name

        -- TODO: code duplicated in update_rocks!
        local rockspec_files =
          luarocks_list_rockspec_files(
              action.local_path .. "/" .. assert(rockspec[1]),
              action.local_path  .. "/"
            )
        assert(#rockspec_files > 1, "rockspec files not found, wrong path")
        -- TODO: debug output, move to logging
        -- writeln_flush("-> Files found in rockspec:")

        local have_rockspec_files_changed = false
        for i = 1, #rockspec_files do
          if
            not current_versions[subproject.name]
            or git_is_file_changed_between_revisions(
                              manifest.project_path .. "/",
                              rockspec_files[i],
                              current_versions[action.source_repo_name],
                              "HEAD"
                            )
          then
            writeln_flush("> Changed file found: ", rockspec_files[i])
            -- here source repo is marked as new and will be tagged
            if action.source_repo_name then
              need_new_versions_for_subprojects[action.source_repo_name] = true
            end
            have_rockspec_files_changed = true
            break
          else
            -- TODO: debug output, move to logging
            -- writeln_flush("> File not changed: ", rockspec_files[i])
          end
        end

        if not have_rockspec_files_changed then
          local rock_types_used =
          {
            ".all.rock";
            ".linux-x86.rock";
            ".linux-x86_64.rock";
          }
          local no_bundle = true
          for i = 1, #rock_types_used do
            local rock_filename = name .. "-" .. data.version .. rock_types_used[i]
            local rock_path = path .. "/" .. rock_filename
            writeln_flush("-> Checking rock bundle: ", rock_path)
            if does_file_exist(rock_path) then
              no_bundle = false
              if
                git_is_file_changed_between_revisions(
                    path .. "/",
                    rock_filename,
                    current_versions[subproject.name],
                    "HEAD"
                  )
              then
                writeln_flush("-> Rock bundle changed: ", rock_path)
                have_rockspec_files_changed = true
                break
              end
            end
          end
          if no_bundle then
            writeln_flush("-> No rock bundle found: ", name)
            have_rockspec_files_changed = true
          end
        end

        if not have_rockspec_files_changed then
          writeln_flush("--> No files changed in ", filename)
        else
          if dry_run then
            writeln_flush("-!!-> DRY RUN: Want to rebuild ", filename)
          else
            writeln_flush("----> Rebuilding `", filename, "'...")
            luarocks_ensure_rock_not_installed_forced(name)
            luarocks_make_in(filename, action.local_path)
          end

          if dry_run then
            writeln_flush("-!!-> DRY RUN: Want to pack ", filename)
          else
            writeln_flush("----> Packing `", filename, "' to `", path, "'...")
            luarocks_pack_to(name, path)
            copy_file_to_dir(action.local_path .. "/" .. filename, path)
            writeln_flush("----> Rebuilding manifest...")
            luarocks_admin_make_manifest(path)

            have_changed_rocks = true
          end

          if rockspec["x-cluster-name"] then
            if dry_run then
              writeln_flush(
                 "-!!-> DRY RUN: Want to remove cluster-specific rock after pack",
                  name
                )
            else
              writeln_flush("----> Removing after cluster-specific rock pack `", name, "'...")
              luarocks_ensure_rock_not_installed_forced(name)
            end
          end

        end -- if #rockspec_files_changed == 0 else
      end -- if rockspec["x-cluster-name"] ~= cluster_info.name else
    end -- for i = 1, #ROCKS do

    if not have_changed_rocks then
      writeln_flush("----> No changed rocks for that rocks manifest ", manifest_path)
    else
      if dry_run then
        writeln_flush(
            "-!!-> DRY RUN: Want to commit added rocks from rocks manifest ",
            manifest_path
          )
      else
        -- TODO: HACK! Add only generated files!
        writeln_flush(
            "----> Committing added rocks from rocks manifest ",
            manifest_path,
            " (path: ", path, ")..."
          )
        git_add_directory(subproject.local_path, path)
        git_commit_with_message(
            subproject.local_path,
            subproject.name .. "/" .. rocks_repo.name .. ": updated rocks"
          )
      end
    end

  end -- handlers.add_rocks_from_pk_rocks_manifest = function

--------------------------------------------------------------------------------

  run_pre_deploy_actions = function(
      manifest,
      cluster_info,
      subproject,
      rocks_repo,
      pre_deploy_actions,
      current_versions,
      need_new_versions_for_subprojects,
      dry_run
    )
    arguments(
        "table", manifest,
        "table", cluster_info,
        "table", subproject,
        "table", rocks_repo,
        "table", pre_deploy_actions,
        "table", current_versions,
        "table", need_new_versions_for_subprojects,
        "boolean", dry_run
      )

    writeln_flush("----> Running pre-deploy actions...")

    for i = 1, #pre_deploy_actions do
      local action = pre_deploy_actions[i]
      local tool_name = assert(action.tool)

      writeln_flush("----> Running pre-deploy action ", tool_name, "...")

      assert(handlers[tool_name], "unknown action")(
          manifest,
          cluster_info,
          subproject,
          rocks_repo,
          current_versions,
          need_new_versions_for_subprojects,
          dry_run,
          action
        )
    end

    writeln_flush("----> Done dunning pre-deploy actions.")
  end
end

--------------------------------------------------------------------------------

return
{
  run_pre_deploy_actions = run_pre_deploy_actions;
}
