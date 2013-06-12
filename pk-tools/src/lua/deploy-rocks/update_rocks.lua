--------------------------------------------------------------------------------
-- update_rocks.lua
-- This file is a part of pk-tools library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------

local log, dbg, spam, log_error
      = import 'pk-core/log.lua' { 'make_loggers' } (
          "update-rocks", "URO"
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

local make_checker
      = import 'lua-nucleo/checker.lua'
      {
        'make_checker'
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

local run_pre_deploy_actions
      = import 'deploy-rocks/run_pre_deploy_actions.lua'
      {
        'run_pre_deploy_actions'
      }

--------------------------------------------------------------------------------

local update_rocks
do
  local check_git_repo_sanity = function(manifest, name, path)
    local checker = make_checker()

    writeln_flush("----> Checking Git repository sanity...")
    git_update_index(path)

    if not manifest.cli_param.debug then
      checker:ensure(
          "must have clean working copy (hint: do commit or reset)",
          not git_is_dirty(path)
        )

      checker:ensure(
          "must have no untracked files (hint: commit or delete them)",
          not git_has_untracked_files(path)
        )

      local tracking_branch_name = checker:ensure(
          "must have tracking branch (hint: push branch to origin)",
          git_get_tracking_branch_name_of_HEAD(path)
        )

      if tracking_branch_name then
        checker:ensure(
            "all changes must be pushed",
            not git_are_branches_different(path, "HEAD", tracking_branch_name)
          )
      end
    end

    assert(checker:result("repository `" .. name .. "' "))
  end

--------------------------------------------------------------------------------

  local update_subproject_is_not_rocks_repo = function(
       manifest,
       cluster_info,
       subproject,
       current_versions,
       dry_run,
       changed_rocks,
       have_changed_rocks,
       need_new_versions_for_subprojects
    )
    local rocks = assert(subproject.provides_rocks)

    if #rocks > 0 then
      -- TODO: move to manifest sanity check?
      if subproject.rockspec_generator then
        if dry_run then
          writeln_flush("!!> DRY RUN: Want to generate rockspecs")
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

      writeln_flush("--> Updating rocks...")
      for i = 1, #rocks do
        local rock = rocks[i]

        -- TODO: code duplicated in run_pre_deploy_actions!
        local rockspec_files = luarocks_list_rockspec_files(
            subproject.local_path .. "/" .. assert(rock.rockspec),
            subproject.local_path  .. "/"
          )
        assert(#rockspec_files > 1, "rockspec files not found, wrong path")
        -- TODO: debug output, move to logging
        -- writeln_flush("-> Files found in rockspec:")
        local have_rockspec_files_changed = false

        for i = 1, #rockspec_files do
          if not current_versions[subproject.name]
            or git_is_file_changed_between_revisions(
                subproject.local_path,
                rockspec_files[i],
                current_versions[subproject.name],
                "HEAD"
              )
          then
            writeln_flush("> Changed file found: ", rockspec_files[i])
            have_rockspec_files_changed = true
            break
          else
            -- TODO: debug output, move to logging
            -- writeln_flush("> File not changed: ", rockspec_files[i])
          end
        end

        if not have_rockspec_files_changed then
          writeln_flush("-> No files changed in ", rock.rockspec)
        else
          have_changed_rocks = true
          if
            manifest.ignore_rocks and
            manifest.ignore_rocks[get_filename_from_path(rock.name)]
          then
            writeln_flush("--> Ignoring `", rock.rockspec, "'")
          else
            changed_rocks[rock.name] = true

            if rock.rockspec_generator then
              if dry_run then
                writeln_flush("!!> DRY RUN: Want to generate rock for ", rock.name)
              else
                writeln_flush("--> Generating rock for ", rock.name, "...")
                local rockspec_generator = is_table(rock.rockspec_generator)
                  and rock.rockspec_generator
                   or { rock.rockspec_generator }
                assert(
                    shell_exec(
                        "cd", subproject.local_path,
                        "&&", unpack(rockspec_generator)
                      ) == 0
                  )
              end
            end
          end

          if dry_run then
            writeln_flush("-!!-> DRY RUN: Want to rebuild", rock.rockspec)
          else
            writeln_flush("----> Rebuilding `", rock.rockspec, "'...")
            luarocks_ensure_rock_not_installed_forced(rock.name)
            luarocks_make_in(rock.rockspec, subproject.local_path)
          end

          if dry_run then
            writeln_flush("-!!-> DRY RUN: Want to pack", rock.rockspec)
          else
            writeln_flush("----> Packing `", rock.rockspec, "'...")
            luarocks_pack_to(rock.name, manifest.local_rocks_repo_path)
            copy_file_to_dir(
                subproject.local_path .. "/" .. rock.rockspec,
                manifest.local_rocks_repo_path
              )
            writeln_flush("----> Rebuilding manifest...")
            luarocks_admin_make_manifest(manifest.local_rocks_repo_path)
          end

          if rock.remove_after_pack then
          -- Needed for foreign-cluster-specific rocks,
          -- so they are not linger in our system
            if dry_run then
              writeln_flush("-!!-> DRY RUN: Want to remove after pack", rock.rockspec)
            else
              writeln_flush("----> Removing after pack `", rock.rockspec, "'...")
              luarocks_ensure_rock_not_installed_forced(rock.name)
            end
          end
        end -- if #rockspec_files_changed == 0 else
      end -- for i = 1, #rocks do
    end -- if #rocks > 0 then

    if have_changed_rocks then
      need_new_versions_for_subprojects[subproject.name] = true
      if dry_run then
        writeln_flush("-!!-> DRY RUN: Want to commit changed rocks")
      else
        -- TODO: HACK! Add only generated files!
        writeln_flush("----> Committing changed rocks...")
        git_add_directory(
            manifest.local_rocks_git_repo_path,
            manifest.local_rocks_repo_path
          )
        git_commit_with_message(
            manifest.local_rocks_git_repo_path,
            "rocks/" .. cluster_info.name
         .. ": updated rocks for " .. subproject.name
          )
      end
    end
    return have_changed_rocks
  end

--------------------------------------------------------------------------------

  local update_subproject_is_rocks_repo = function(
       manifest,
       cluster_info,
       subproject,
       current_versions,
       dry_run,
       changed_rocks,
       have_changed_rocks,
       need_new_versions_for_subprojects
    )
    assert(not subproject.provides_rocks)
    assert(not subproject.rockspec_generator)
    local name = subproject.name
    local path = assert(subproject.local_path)

    -- TODO: move to manifest sanity check?
    if not is_table(subproject.provides_rocks_repo) then
      subproject.provides_rocks_repo = { { name = subproject.provides_rocks_repo } }
    end

    for i = 1, #subproject.provides_rocks_repo do
      local have_changed_rocks_in_repo = false
      local rocks_repo = subproject.provides_rocks_repo[i].name

      if not subproject.provides_rocks_repo[i].pre_deploy_actions then
        writeln_flush("---> No pre-deploy actions for ", name, rocks_repo)
      else
        writeln_flush("---> Running pre-deploy actions for ", name, rocks_repo)

        run_pre_deploy_actions(
            manifest,
            cluster_info,
            subproject,
            subproject.provides_rocks_repo[i],
            subproject.provides_rocks_repo[i].pre_deploy_actions,
            current_versions,
            need_new_versions_for_subprojects,
            dry_run
          )
      end

      writeln_flush("---> Searching for rocks in repo `", rocks_repo, "'...")

      local rock_files, rockspec_files =
        find_rock_files_in_subproject(path, rocks_repo)

      writeln_flush("---> Determining changed rocks...")

      local need_to_reinstall = { }
      for i = 1, #rock_files do
        local rock_file = rock_files[i]

        if
          manifest.ignore_rocks and manifest.ignore_rocks[
              get_filename_from_path(rock_file.name)
            ]
        then
          writeln_flush("--> Ignoring `", rock_file.name, "'")
        elseif
          not current_versions[name]
          or git_is_file_changed_between_revisions(
              path,
              rock_file.filename,
              current_versions[name],
              "HEAD"
            )
        then
          if not changed_rocks[rock_file.name] then
            writeln_flush("--> Changed or new `", rock_file.name, "'.")
          end
          changed_rocks[rock_file.name] = true
          need_to_reinstall[rock_file.name] = true
          have_changed_rocks = true
          have_changed_rocks_in_repo = true
        else
          writeln_flush("--> Not changed `", rock_file.name, "'.")
        end
      end

      if not next(need_to_reinstall) then
        writeln_flush("---> No changed rocks detected.")
      else
        writeln_flush("---> Reinstalling changed rocks...")

        for rock_name, _ in pairs(need_to_reinstall) do
          local rockspec =
            assert(
                rockspec_files[rock_name],
                "rock without rockspec "..rock_name
              )
          if dry_run then
            writeln_flush("!!-> DRY RUN: Want to reinstall", rockspec)
          else
            writeln_flush("---> Reinstalling `", rockspec, "'...")
            luarocks_ensure_rock_not_installed_forced(rock_name)
            luarocks_install_from(rock_name, path .. "/" .. rocks_repo)
          end

          if dry_run then
            writeln_flush("!!-> DRY RUN: Want to pack", rockspec)
          else
            writeln_flush(
                "---> Packing `", rockspec, "' to `",
                manifest.local_rocks_repo_path, "'..."
              )
            luarocks_pack_to(rock_name, manifest.local_rocks_repo_path)
            if path ~= manifest.local_rocks_repo_path then
              copy_file_to_dir(path .. "/" .. rockspec, manifest.local_rocks_repo_path)
            else
              writeln_flush(
                  "Path " .. path .. " is the same as local repository path",
                  rockspec
                )
            end
            writeln_flush("---> Rebuilding manifest...")
            luarocks_admin_make_manifest(manifest.local_rocks_repo_path)
          end
        end
      end

      if have_changed_rocks_in_repo then
        need_new_versions_for_subprojects[name] = true
        if dry_run then
          writeln_flush("!!-> DRY RUN: Want to commit changed rocks")
        else
          -- TODO: HACK! Add only generated files!
          writeln_flush("---> Committing changed rocks...")
          git_add_directory(
              manifest.local_rocks_git_repo_path,
              manifest.local_rocks_repo_path
            )
          git_commit_with_message(
              manifest.local_rocks_git_repo_path,
              "rocks/" .. cluster_info.name .. ": updated rocks for " .. name
            )
        end
      end
    end
    return have_changed_rocks, changed_rocks
  end

--------------------------------------------------------------------------------

  update_rocks = function(manifest, cluster_info, current_versions, dry_run)
    arguments(
        "table", manifest,
        "table", cluster_info,
        "table", current_versions,
        "boolean", dry_run
      )

    writeln_flush("----> Updating local rocks repository...")

    local changed_rocks = { }
    local need_new_versions_for_subprojects = { }

    local subprojects = manifest.subprojects

    if not manifest.cli_param.debug then
      writeln_flush("----> Checking git repo sanity for subprojects...")

      for i = 1, #subprojects do
        local subproject = subprojects[i]
        local name = subproject.name

        writeln_flush("---> Checking subproject git repo sanity for `", name, "'...")

        check_git_repo_sanity(manifest, name, subproject.local_path)
      end
    else
      writeln_flush("----> Checking git repo sanity for subprojects skipped (debug run)")
    end

    writeln_flush("----> Collecting data from subprojects...")

    for i = 1, #subprojects do
      local subproject = subprojects[i]
      local name = subproject.name

      if subproject.no_deploy then
        writeln_flush("---> Skipping no-deploy subproject `", name, "'.")
      else
        writeln_flush("---> Collecting data from `", name, "'...")

        local path = assert(subproject.local_path)
        if
          current_versions[name] and
          not git_are_branches_different(path, "HEAD", current_versions[name])
        then
          writeln_flush("No changes detected, skipping")
        else

          if not current_versions[name] then
            writeln_flush("New subproject")
          else
            writeln_flush("Changes are detected")
          end

          local have_changed_rocks = false

          if subproject.provides_rocks_repo then
            have_changed_rocks = update_subproject_is_rocks_repo(
                manifest,
                cluster_info,
                subproject,
                current_versions,
                dry_run,
                changed_rocks,
                have_changed_rocks,
                need_new_versions_for_subprojects
              )
          elseif
            subproject.provides_rocks and
            not tequals(subproject.provides_rocks, { })
          then
            have_changed_rocks = update_subproject_is_not_rocks_repo(
                manifest,
                cluster_info,
                subproject,
                current_versions,
                dry_run,
                changed_rocks,
                have_changed_rocks,
                need_new_versions_for_subprojects
              )
          else
            error("Empty subproject without no-deploy mark found: " .. name)
          end

        end -- if git_are_branches_different("HEAD", current_versions[name])
      end -- if subproject.no_deploy else
    end -- for i = 1, #subprojects do

    if next(changed_rocks) then
      if dry_run then
        writeln_flush("-!!-> DRY RUN: Want to rebuild manifest")
      else
        writeln_flush("---> Rebuilding manifest...")
        luarocks_admin_make_manifest(manifest.local_rocks_repo_path)

        -- TODO: HACK! Add only generated files!
        git_add_directory(
            manifest.local_rocks_git_repo_path,
            manifest.local_rocks_repo_path
          )
      end

      git_update_index(manifest.local_rocks_git_repo_path)
      if
        not git_is_directory_dirty(
            manifest.local_rocks_git_repo_path,
            manifest.local_rocks_repo_path
         )
      then
        writeln_flush("---> Manifest not changed")
      else
        if dry_run then
          writeln_flush("!!-> DRY RUN: Want to commit changed manifest")
        else
          writeln_flush("---> Comitting changed manifest...")

          git_commit_with_message(
              manifest.local_rocks_git_repo_path,
              "rocks/" .. cluster_info.name .. ": updated manifest"
            )
        end
      end

      if dry_run then
        writeln_flush("!!-> DRY RUN: Want to push manifest git repo")
      elseif manifest.cli_param.local_only then
         writeln_flush("-!!-> LOCAL ONLY: Pushing skipped")
      else
        writeln_flush("---> Pushing manifest git repo...")
        git_push_all(manifest.local_rocks_git_repo_path)
      end
    end

    return changed_rocks, need_new_versions_for_subprojects
  end
end

--------------------------------------------------------------------------------

return
{
  update_rocks = update_rocks;
}
