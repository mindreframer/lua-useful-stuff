--------------------------------------------------------------------------------
-- deploy_rocks.lua
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
      tclone
      = import 'lua-nucleo/table-utils.lua'
      {
        'tset',
        'timapofrecords',
        'twithdefaults',
        'tkeys',
        'tclone'
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

local shell_read
      = import 'lua-aplicado/shell.lua'
      {
        'shell_read'
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

local luarocks_get_rocknames_in_manifest
      = import 'lua-aplicado/shell/luarocks.lua'
      {
        'luarocks_get_rocknames_in_manifest'
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

local deploy_to_cluster
      = import 'deploy-rocks/deploy_to_cluster.lua'
      {
        'deploy_to_cluster'
      }

local update_rocks
      = import 'deploy-rocks/update_rocks.lua'
      {
        'update_rocks'
      }

--------------------------------------------------------------------------------
 -- TODO: Uberhack! Must be in path. Wrap to a rock and install.
 --       (Or, better, replace with Lua code)
local GIT_TAG_TOOL_PATH = "pk-git-tag-version"

--------------------------------------------------------------------------------

local git_get_version_increment = function(path, suffix, majority)
  return trim(shell_read(
      "cd", path,
      "&&", GIT_TAG_TOOL_PATH, suffix, majority, "--dry-run"
    ))
end

local git_tag_version_increment = function(path, suffix, majority)
  return trim(shell_read(
      "cd", path,
      "&&", GIT_TAG_TOOL_PATH, suffix, majority
    ))
end

local git_tag_version_increment_local = function(path, suffix, majority)
  return trim(shell_read(
      "cd", path,
      "&&", GIT_TAG_TOOL_PATH, suffix, majority, "--no-push"
    ))
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local get_cluster_info = function(manifest, cluster_name)
  local clusters = timapofrecords(manifest.clusters, "name")
  return assert(clusters[cluster_name], "cluster not found")
end

--------------------------------------------------------------------------------

local load_current_versions = function(manifest, cluster_info)
  local path = manifest.local_cluster_versions_path .. "/versions-current.lua"
  writeln_flush("----> Loading versions from `", path, "'...")

  local versions = load_table_from_file(path)

  for k, v in pairs(versions) do
    -- TODO: Validate that all repositories are known.
    writeln_flush(k, " ", v)
  end

  return versions
end

--------------------------------------------------------------------------------
-- Assuming we're operating under atomic lock
local write_current_versions = function(manifest, cluster_info, new_versions)
  local filename = manifest.local_cluster_versions_path
    .. "/versions-" .. os.date("%Y-%m-%d-%H-%M-%S")

  local i = 1
  while does_file_exist(filename .. "-" .. i .. ".lua") do
    i = i + 1
    assert(i < 1000)
  end

  filename = filename .. "-" .. i .. ".lua"

  assert(
      write_file(
          filename,
          "return\n" .. tpretty(new_versions, "  ", 80) .. "\n"
        )
    )

  return filename
end

--------------------------------------------------------------------------------

local update_version_symlink = function(
    manifest,
    cluster_info,
    new_versions_filename
  )
  local expected_path = manifest.local_cluster_versions_path
  local versions_current_filename = expected_path .. "/versions-current.lua"

  if new_versions_filename:sub(1, 1) ~= "/" then -- TODO: ?!
    new_versions_filename = assert(
        manifest.project_path,
        'project_path is not defined in the manifest (perhaps system valiable $PROJECT_PATH is missing)'
      )
      .. "/" .. new_versions_filename
  end

  local path, filename = splitpath(new_versions_filename)
  assert(
      path == expected_path,
      "Path to new version-current.lua doesn't match manifest.local_cluster_versions_path"
    )

  remove_file(versions_current_filename)
  create_symlink_from_to(filename, versions_current_filename)
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local deploy_rocks_from_code, deploy_rocks_from_versions_filename
do
  local calculate_update_rocks_from_versions = function(
      manifest,
      current_versions,
      new_versions,
      dry_run
    )
    arguments(
        "table", manifest,
        "table", current_versions,
        "table", new_versions,
        "boolean", dry_run
      )

    writeln_flush("----> Checking for changed projects...")

    local changed_rocks_set, changed_subprojects = { }, { }

    for name, version in pairs(new_versions) do
      -- TODO: Handle rock removal.

      local old_version = current_versions[name]
      if not old_version or old_version ~= version then
        writeln_flush(
            "Subproject `", name, "' version is changed from `",
            old_version or "(not installed)", "' to `", version, "'."
          )
        changed_subprojects[#changed_subprojects + 1] = name
      end
    end

    writeln_flush("----> Calculating rocks to update...")

    local subprojects = timapofrecords(manifest.subprojects, "name")

    -- TODO: Use git diff instead! There could be non-project rocks!

    for i = 1, #changed_subprojects do
      local name = changed_subprojects[i]
      local subproject = assert(subprojects[name])

      -- TODO: Hack. Do this at load time!
      if subproject.provides_rocks_repo then
        assert(not subproject.provides_rocks)
        assert(not subproject.rockspec_generator)

        if not is_table(subproject.provides_rocks_repo) then
          subproject.provides_rocks_repo = { name = subproject.provides_rocks_repo }
        end

        subproject.local_path =
          subproject.local_path or manifest.project_path .. "/" .. name

        for i = 1, #subproject.provides_rocks_repo do
          local rocks_repo = subproject.provides_rocks_repo[i].name

          local names = luarocks_get_rocknames_in_manifest(
  -- TODO: Really Bad! This will trigger full reinstall! Detect changed rocks!
              subproject.local_path .. "/" .. rocks_repo .. "/manifest"
            )
          for i = 1, #names do
            local name = names[i]
            changed_rocks_set[name] = true

            writeln_flush("Marking rock `", name, "' as changed")
          end
        end
      else
        local rocks = assert(subproject.provides_rocks)
        for i = 1, #rocks do
          local rock = rocks[i]
          changed_rocks_set[rock.name] = true

          writeln_flush("Marking rock `", rock.name, "' as changed")

          -- TODO: Rebuild rock? Note that we would have
          --       to checkout a tag to a temporary directory then.
        end
      end
    end

    return changed_rocks_set, tset(changed_subprojects)
  end

--------------------------------------------------------------------------------

  local tag_new_versions = function(manifest, cluster_info, subprojects_set, dry_run)
    writeln_flush("----> Tagging new versions...")

    local new_versions = { }

    local subprojects = manifest.subprojects
    for i = 1, #subprojects do
      local subproject = subprojects[i]
      local name = subproject.name
      if not subprojects_set[name] then
        writeln_flush("----> Subproject `", name, "' not changed, skipping")
      else
        local version

        if dry_run then
          version =
            git_get_version_increment(
                subproject.local_path,
                cluster_info.version_tag_suffix,
                "build"  -- TODO: Do not hardcode "build".
              )
          writeln_flush(
              "-!!-> DRY RUN: Want to tag subproject `", name,
              "' with `", version, "'"
            )
        elseif manifest.cli_param.local_only then
          version =
            git_tag_version_increment_local(
                subproject.local_path,
                cluster_info.version_tag_suffix,
                "build" -- TODO: Do not hardcode "build".
              )
          writeln_flush("----> Subproject `", name, "' tagged locally `", version, "'")
        else
          version =
            git_tag_version_increment(
                subproject.local_path,
                cluster_info.version_tag_suffix,
                "build" -- TODO: Do not hardcode "build".
              )
          writeln_flush("----> Subproject `", name, "' tagged `", version, "'")
        end

        new_versions[name] = version
      end
    end

    return new_versions
  end


--------------------------------------------------------------------------------

  local deploy_new_versions = function(
      manifest,
      cluster_info,
      changed_rocks_set,
      new_versions_filename,
      commit_new_versions,
      dry_run,
      run_deploy_without_question
    )

    deploy_to_cluster(
        manifest,
        cluster_info,
        {
          dry_run = dry_run;
          changed_rocks_set = changed_rocks_set;
          run_deploy_without_question = run_deploy_without_question;
        }
      )

    if not commit_new_versions then
      writeln_flush("-!!-> WARNING: Not updating current version as requested")
    else
      if dry_run then
        writeln_flush("-!!-> DRY RUN: Want to update version-current.lua symlink")
      else
        writeln_flush("----> Updating version-current.lua symlink.")
        update_version_symlink(manifest, cluster_info, new_versions_filename)
      end

      if dry_run then
        writeln_flush("-!!-> DRY RUN: Want to commit versions and push")
      else
        writeln_flush("----> Adding versions")
        git_add_directory(
            manifest.local_cluster_versions_git_repo_path,
            manifest.local_cluster_versions_path
          )

        writeln_flush("----> Committing")
        git_commit_with_message(
            manifest.local_cluster_versions_git_repo_path,
            "cluster/" .. cluster_info.name .. ": updated versions after deployment"
          )

        if manifest.cli_param.local_only then
         writeln_flush("-!!-> LOCAL ONLY: Pushing skipped")
        else
          writeln_flush("----> Pushing")
          git_push_all(manifest.local_cluster_versions_git_repo_path)
        end
      end
    end
  end

--------------------------------------------------------------------------------

  deploy_rocks_from_code = function(manifest, cluster_name, dry_run)
    arguments(
        "table", manifest,
        "string", cluster_name,
        "boolean", dry_run
      )

    writeln_flush("----> Preparing to deploy to `", cluster_name, "'...")

    local cluster_info = get_cluster_info(manifest, cluster_name)

    local current_versions = load_current_versions(manifest, cluster_info)

    local changed_rocks_set, subprojects_to_be_given_new_versions_set = update_rocks(
        manifest, cluster_info, current_versions, dry_run
      )
    local run_deploy_without_question = nil

    if not next(subprojects_to_be_given_new_versions_set) then
      assert(not next(changed_rocks_set)) -- TODO: ?!
      writeln_flush("----> Nothing to deploy, you can deploy to check system integrity.")
      if ask_user(
          "\n\nDO YOU WANT TO DEPLOY TO `"
       .. cluster_info.name .. "'? (Not recommended!)",
          { "y", "n" },
          "n"
        ) ~= "y"
      then
        return
      else
        run_deploy_without_question = true
      end
    end

    local new_versions = twithdefaults(
        tag_new_versions(
            manifest,
            cluster_info,
            subprojects_to_be_given_new_versions_set,
            dry_run
          ),
        current_versions
      )

    local new_versions_filename

    if dry_run then
      writeln_flush("-!!-> DRY RUN: Want to write versions file:")
      writeln_flush("return\n" .. tpretty(new_versions, '  ', 80))
    else
      -- Note that updated file is not linked as current and
      -- committed until deployment succeeds
      new_versions_filename = write_current_versions(manifest, cluster_info, new_versions)
    end

    deploy_new_versions(
        manifest,
        cluster_info,
        changed_rocks_set,
        new_versions_filename,
        true, -- Commit new versions
        dry_run,
        run_deploy_without_question
      )
  end

--------------------------------------------------------------------------------

  deploy_rocks_from_versions_filename = function(
      manifest,
      cluster_name,
      new_versions_filename,
      commit_new_versions,
      dry_run
    )
    arguments(
        "table", manifest,
        "string", cluster_name,
        "string", new_versions_filename,
        "boolean", commit_new_versions,
        "boolean", dry_run
      )

    writeln_flush("----> Preparing to deploy to `", cluster_name, "'...")

    local cluster_info = get_cluster_info(manifest, cluster_name)

    local current_versions = load_current_versions(manifest, cluster_info)
    local new_versions = load_table_from_file(new_versions_filename)

    local changed_rocks_set, changed_subprojects_set
      = calculate_update_rocks_from_versions(
        manifest, current_versions, new_versions, dry_run
      )

    -- TODO: Look at the rocks, not at subprojects!
    if not next(changed_subprojects_set) then
      assert(not next(changed_rocks_set)) -- TODO: ?!
      writeln_flush("----> Nothing to deploy, bailing out.")
      return
    end

    deploy_new_versions(
        manifest,
        cluster_info,
        changed_rocks_set,
        new_versions_filename,
        commit_new_versions,
        dry_run
      )
  end
end

--------------------------------------------------------------------------------

return
{
  deploy_rocks_from_versions_filename = deploy_rocks_from_versions_filename;
  deploy_rocks_from_code = deploy_rocks_from_code;
}
