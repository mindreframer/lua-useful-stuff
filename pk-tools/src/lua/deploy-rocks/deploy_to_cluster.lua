--------------------------------------------------------------------------------
-- deploy_to_cluster.lua
-- This file is a part of pk-tools library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------

local log, dbg, spam, log_error
      = import 'pk-core/log.lua' { 'make_loggers' } (
          "deploy-to-cluster", "DTC"
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

local assert_is_string
      = import 'lua-nucleo/typeassert.lua'
      {
        'assert_is_string'
      }

local tpretty
      = import 'lua-nucleo/tpretty.lua'
      {
        'tpretty'
      }

local fill_curly_placeholders
      = import 'lua-nucleo/string.lua'
      {
        'fill_curly_placeholders'
      }

local timapofrecords,
      tkeys,
      tclone,
      tsetpath,
      tgetpath
      = import 'lua-nucleo/table-utils.lua'
      {
        'timapofrecords',
        'tkeys',
        'tclone',
        'tsetpath',
        'tgetpath'
      }

local make_config_environment
      = import 'lua-nucleo/sandbox.lua'
      {
        'make_config_environment'
      }

local write_file,
      does_file_exist
      = import 'lua-aplicado/filesystem.lua'
      {
        'write_file',
        'does_file_exist'
      }

local shell_exec,
      shell_read,
      shell_exec_no_subst,
      shell_read_no_subst,
      shell_format_command,
      shell_format_command_no_subst
      = import 'lua-aplicado/shell.lua'
      {
        'shell_exec',
        'shell_read',
        'shell_exec_no_subst',
        'shell_read_no_subst',
        'shell_format_command',
        'shell_format_command_no_subst'
      }

local shell_exec_remote,
      shell_read_remote
      = import 'lua-aplicado/shell/remote.lua'
      {
        'shell_exec_remote',
        'shell_read_remote'
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

local copy_file_to_dir,
      remove_file,
      create_symlink_from_to
      = import 'lua-aplicado/shell/filesystem.lua'
      {
        'copy_file_to_dir',
        'remove_file',
        'create_symlink_from_to'
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
--------------------------------------------------------------------------------
-- Actions:
--   local_exec
--   remote_exec
--   deploy_rocks
--   ensure_file_access_rights
--   ensure_dir_access_rights
--------------------------------------------------------------------------------

local deploy_to_cluster
do

  local remote_ensure_sudo_is_passwordless_cached = function(
      project_name,
      cluster_name,
      machine_name,
      machine_url,
      cache
    )
    arguments(
        "string", project_name,
        "string", cluster_name,
        "string", machine_name,
        "string", machine_url,
        "table", cache
      )

    if
      tgetpath(
          cache,
          "projects", project_name,
          "clusters", cluster_name,
          "machines", machine_name,
          "sudo_is_passwordless")
    then
      return
    end

    -- Hint: To fix do:
    -- $ sudo visudo
    -- Replace %sudo ALL=(ALL) ALL
    -- with %sudo ALL=NOPASSWD: ALL
    assert(
        shell_read_remote(machine_url, "sudo", "echo", "-n", "yo") == "yo",
        "remote sudo is not passwordless (or some obscure error occured)"
      )

    tsetpath(
        cache,
        "projects", project_name,
        "clusters", cluster_name,
        "machines", machine_name,
        "sudo_is_passwordless")
     cache
       .projects[project_name]
       .clusters[cluster_name]
       .machines[machine_name]
       .sudo_is_passwordless = true
  end

--------------------------------------------------------------------------------

  local fill_cluster_info_placeholders = function(
      manifest, cluster_info, machine, template
    )
    return fill_curly_placeholders( -- TODO: Add more?
        template,
        {
          INTERNAL_CONFIG_HOST = cluster_info.internal_config_host;
          INTERNAL_CONFIG_PORT = cluster_info.internal_config_port;
          INTERNAL_CONFIG_DEPLOY_HOST = cluster_info.internal_config_deploy_host;
          INTERNAL_CONFIG_DEPLOY_PORT = cluster_info.internal_config_deploy_port;
          MACHINE_NODE_ID = assert(machine.node_id);
          MACHINE_NAME = assert(machine.name);
        }
      )
  end

  local action_handlers = { }

--local_exec--------------------------------------------------------------------

  action_handlers.local_exec =
    function(
        manifest,
        cluster_info,
        param,
        machine,
        role_args,
        action
      )
    local commands = action
    assert(#commands > 0)

    for i = 1, #commands do
      local command = commands[i]
      if not is_table(command) then
        command = { command }
      else
        command = tclone(command)
      end

      for i = 1, #command do
        command[i] = fill_cluster_info_placeholders(
            manifest, cluster_info, machine, command[i]
          )
      end

      -- Overhead to print the command to user.
      local command_str = shell_format_command(unpack(command))

      if param.dry_run then
        writeln_flush("-!!-> DRY RUN: Want to run locally: `" .. command_str .. "'")
      else
        writeln_flush("-> Running locally: `" .. command_str .. "'")

        -- TODO: Hack! Run something lower-level then, don't format command twice
        assert(shell_exec(unpack(command)) == 0)
      end
    end
  end

--remote_exec-------------------------------------------------------------------

  action_handlers.remote_exec = function(
      manifest,
      cluster_info,
      param,
      machine,
      role_args,
      action
    )
    local commands = action
    assert(#commands > 0)

    for i = 1, #commands do
      local command = commands[i]
      if not is_table(command) then
        command = { command }
      else
        command = tclone(command)
      end

      for i = 1, #command do
        command[i] = fill_cluster_info_placeholders(
            manifest, cluster_info, machine, command[i]
          )
      end

      -- Overhead to print the command to user.
      local command_str = shell_format_command(unpack(command))

      if param.dry_run then
        writeln_flush(
            "-!!-> DRY RUN: Want to run remotely: `" .. command_str ..
            "' on `" .. machine.name .. "'"
          )
      else
        writeln_flush(
            "-> Running remotely: `" .. command_str ..
            "' on `" .. machine.name .. "'"
          )

        assert(shell_exec_remote(machine.external_url, unpack(command)) == 0)
      end
    end
  end

--deploy_rocks------------------------------------------------------------------

  action_handlers.deploy_rocks = function(
      manifest,
      cluster_info,
      param,
      machine,
      role_args,
      action
    )
    local rocks_must_be_installed = { }
    for i = 1, #action do
      rocks_must_be_installed[i] = fill_cluster_info_placeholders(
          manifest, cluster_info, machine, action[i]
        )
    end
    assert(#rocks_must_be_installed > 0, "deploy_rocks: no rocks specified")

    local dry_run = param.dry_run

    -- TODO: Hack! Store state elsewhere!
    machine.deployed_rocks_set = machine.deployed_rocks_set or { }
    if not machine.installed_rocks_set then
      assert(not machine.duplicate_rocks_set)
      writeln_flush(
          "-> Reading remote list of installed rocks from `",
          machine.external_url, "'"
        )
      machine.installed_rocks_set, machine.duplicate_rocks_set = luarocks_parse_installed_rocks(
          remote_luarocks_list_installed_rocks(
              machine.external_url
            )
        )
    else
      assert(machine.duplicate_rocks_set)
      writeln_flush(
          "-> Using cached remote list of installed rocks for `",
          machine.external_url, "'"
        )
    end

    local installed_rocks_set, duplicate_rocks_set =
      machine.installed_rocks_set, machine.duplicate_rocks_set

    -- TODO: HACK! Don't rely on this, rely on description in role! (?!)
    --       But what about third-party rocks then?
    local installed_rocks = tkeys(installed_rocks_set)
    local duplicate_rocks = tkeys(duplicate_rocks_set)

    local changed_rocks_set = param.changed_rocks_set

    local rocks_changed = false

    if duplicate_rocks and #duplicate_rocks > 0 then
      writeln_flush("-> WARNING! Duplicate installed rocks detected")
      for i = 1, #duplicate_rocks do
        local rock_name = duplicate_rocks[i]

        if changed_rocks_set[rock_name] then
          writeln_flush("-> Delaying reinstall of remote duplicate rock " .. rock_name .. "'")
        elseif machine.deployed_rocks_set[rock_name] then
          writeln_flush(
              "-> Skipping reinstall of remote duplicate rock " .. rock_name
           .. "': marked as reinstalled by someone else"
            )
        else
          if dry_run then
            writeln_flush(
                "-!!-> DRY RUN: Want to reinstall remote duplicate rock: `"
             .. rock_name .. "'"
              )
          else
            writeln_flush("-> Removing remote duplicate rock " .. rock_name .. "'")
            remote_luarocks_remove_forced(machine.external_url, rock_name)
            writeln_flush("-> Installing remote duplicate rock " .. rock_name .. "'")
            remote_luarocks_install_from(
                machine.external_url,
                rock_name,
                cluster_info.rocks_repo_url
              )
            machine.deployed_rocks_set[rock_name] = true
            rocks_changed = true
          end
        end
      end
    end

    for i = 1, #rocks_must_be_installed do
      local rock_name = assert_is_string(rocks_must_be_installed[i])
      if not installed_rocks_set[rock_name] then
        if machine.deployed_rocks_set[rock_name] then
          writeln_flush(
              "-> Skipping mandatory rock `".. rock_name
           .. "': marked as installed by someone else"
            )
        else
          writeln_flush(
              "-> WARNING! Not installed mandatory rock `" .. rock_name
           .. "' detected"
            )
          if dry_run then
            writeln_flush(
                "-!!-> DRY RUN: Want to install missing rock: `"
             .. rock_name .. "'"
              )
          else
            writeln_flush("-> Installing missing rock " .. rock_name .. "'")
            remote_luarocks_install_from(
                machine.external_url,
                rock_name,
                cluster_info.rocks_repo_url
              )
            machine.deployed_rocks_set[rock_name] = true
            rocks_changed = true
          end
        end
      end
    end

    local changed_rocks_list = tkeys(changed_rocks_set)
    for i = 1, #changed_rocks_list do
      local rock_name = changed_rocks_list[i]
      if not installed_rocks_set[rock_name] then
        writeln_flush(
            "-> Skipping changed rock ".. rock_name
         .. "': not installed here"
          )
      elseif machine.deployed_rocks_set[rock_name] then
        writeln_flush(
            "-> Skipping changed rock `" .. rock_name
         .. "': marked as updated by someone else")
      else
        if dry_run then
          writeln_flush(
              "-!!-> DRY RUN: Want to reinstall remote changed rock: `"
           .. rock_name .. "'"
            )
        else
          writeln_flush("-> Removing remote changed rock " .. rock_name .. "'")
          remote_luarocks_remove_forced(machine.external_url, rock_name)
          writeln_flush("-> Installing remote changed rock " .. rock_name .. "'")
          remote_luarocks_install_from(
              machine.external_url,
              rock_name,
              cluster_info.rocks_repo_url
            )
          machine.deployed_rocks_set[rock_name] = true
          rocks_changed = true
        end
      end
    end

    if not rocks_changed then
      writeln_flush("-> No changes, skipping.")
    else
      writeln_flush("-> Marking `" .. machine.name .. "' to be handled at post-deploy")
      machine.need_post_deploy = true -- TODO: HACK! Store state elsewhere!
    end
  end

--ensure_file_access_rights-----------------------------------------------------

  action_handlers.ensure_file_access_rights = function(
      manifest,
      cluster_info,
      param,
      machine,
      role_args,
      action
    )
    local dry_run = param.dry_run

    action.file = fill_cluster_info_placeholders(
        manifest, cluster_info, machine, action.file
      )

    if dry_run then
      writeln_flush(
          "-!!-> DRY RUN: Want to ensure file access rights `", action.file,
          "' on `" .. machine.name .. "'"
        )
    else
      -- TODO: Not flexible enough?
      writeln_flush("-> Touching `", action.file, "' on `" .. machine.name .. "'")
      assert(shell_exec_remote(
          machine.external_url, "sudo", "touch", assert(action.file)
        ) == 0)

      writeln_flush(
          "-> Chmodding `", action.file,
          "' to ", action.mode,
          " on `" .. machine.name .. "'"
        )
      assert(shell_exec_remote(
          machine.external_url, "sudo", "chmod", assert(action.mode), assert(action.file)
        ) == 0)

      local owner = assert(action.owner_user) .. ":" .. assert(action.owner_group)

      writeln_flush(
          "-> Chowning `", action.file,
          "' to `", owner, "' on `" .. machine.name .. "'"
        )
      assert(shell_exec_remote(
          machine.external_url, "sudo", "chown", owner, assert(action.file)
        ) == 0)
    end
  end

--ensure_dir_access_rights-----------------------------------------------------

  action_handlers.ensure_dir_access_rights = function(
      manifest,
      cluster_info,
      param,
      machine,
      role_args,
      action
    )
    local dry_run = param.dry_run

    local directory = fill_cluster_info_placeholders(
        manifest, cluster_info, machine, action.dir
      )
    if dry_run then
      writeln_flush(
          "-!!-> DRY RUN: Want to ensure dir access rights `", directory,
          "' on `" .. machine.name .. "'"
        )
    else
      -- TODO: check if directory already exists?
      writeln_flush("-> Mkdir `", directory, "' on `" .. machine.name .. "'")
      assert(shell_exec_remote(
          machine.external_url, "sudo", "mkdir", "-p", assert(directory)
        ) == 0)

      writeln_flush(
          "-> Chmodding `", directory,
          "' to ", action.mode,
          " on `" .. machine.name .. "'"
        )
      assert(shell_exec_remote(
          machine.external_url, "sudo", "chmod", assert(action.mode), assert(directory)
        ) == 0)

      local owner = assert(action.owner_user) .. ":" .. assert(action.owner_group)

      writeln_flush(
          "-> Chowning `", directory,
          "' to `", owner, "' on `" .. machine.name .. "'"
        )
      assert(shell_exec_remote(
          machine.external_url, "sudo", "chown", owner, assert(directory)
        ) == 0)
    end
  end

--------------------------------------------------------------------------------

  deploy_to_cluster = function(
      manifest,
      cluster_info,
      param
    )

    local dry_run = param.dry_run

    if not dry_run then
      if ask_user( -- TODO: Make interactivity configurable,
                   --       don't want to press this on developer machine each time
          "\n\nABOUT TO DEPLOY TO `" .. cluster_info.name .. "'. ARE YOU SURE?",
          { "y", "n" },
          "n"
        ) ~= "y"
      then
        error("Aborted.")
      end
    end

    writeln_flush("----> DEPLOYING TO CLUSTER `", cluster_info.name, "'...")

    local roles = timapofrecords(manifest.roles, "name")

    local machines = cluster_info.machines

    for i = 1, #machines do
      local machine = machines[i]

      writeln_flush(
          "---> DEPLOYING TO MACHINE `", machine.name,
          "' from `", cluster_info.name, "'..."
        )

      local machine_roles = machine.roles
      for i = 1, #machine_roles do
        local role_args = machine_roles[i]
        writeln_flush(
            "--> Deploying role `", role_args.name,
            "' to `", machine.name, "'..."
          )

        local role_info = assert(roles[role_args.name], "unknown role")
        local deployment_actions = role_info.deployment_actions

        if #deployment_actions == 0 then
          writeln_flush("Role deployment actions are empty")
        else
          -- TODO: Hack? Fix error handling instead!
          if not machine.sudo_checked then -- TODO: Hack. Store state elsewhere
            -- TODO: Do this only if there is an action that requires remote sudo!
            writeln_flush(
                "--> Checking that sudo is passwordless on `",
                machine.name, "'..."
              )
            remote_ensure_sudo_is_passwordless_cached(
                  manifest.PROJECT_TITLE,
                  cluster_info.name,
                  machine.name,
                  assert(machine.external_url),
                  manifest.cache
                )
            machine.sudo_checked = true
          end

          for i = 1, #deployment_actions do
            local action = deployment_actions[i]
            writeln_flush(
                "--> Running role `", role_args.name,
                "' action ", i, ":, ", action.tool, "..."
              )

            assert(action_handlers[action.tool], "unknown tool")(
                manifest,
                cluster_info,
                param,
                machine,
                role_args,
                action
              )
          end
        end

        writeln_flush(
            "--> Done deploying role `", role_args.name,
            "' to `", machine.name, "'..."
          )
      end

      writeln_flush(
          "---> DONE DEPLOYING TO MACHINE `", machine.name,
          "' from `", cluster_info.name, "'..."
        )
    end

    for i = 1, #machines do
      local machine = machines[i]

      if not machine.need_post_deploy then
        writeln_flush(
            "---> Machine `", machine.name,
            "' from `", cluster_info.name, "' does not need post-deploy."
          )
      else
        writeln_flush(
            "---> RUNNING POST-DEPLOY ON `", machine.name,
            "' from `", cluster_info.name, "'..."
          )

        local machine_roles = machine.roles
        for i = 1, #machine_roles do
          local role_args = machine_roles[i]
          writeln_flush(
              "--> Post-deploying role `", role_args.name,
              "' to `", machine.name, "'..."
            )

          local role_info = assert(roles[role_args.name], "unknown role")
          local post_deploy_actions = role_info.post_deploy_actions

          if not post_deploy_actions or #post_deploy_actions == 0 then
            writeln_flush("Role post-deploy action is empty")
          else
            if not machine.sudo_checked then
              -- TODO: Do this only if there is an action that requires remote sudo!
              writeln_flush(
                  "--> Checking that sudo is passwordless on `",
                  machine.name, "'..."
                )
              remote_ensure_sudo_is_passwordless_cached(
                  manifest.PROJECT_TITLE,
                  cluster_info.name,
                  machine.name,
                  assert(machine.external_url),
                  manifest.cache
                )
              machine.sudo_checked = true
            end

            for i = 1, #post_deploy_actions do
              local action = post_deploy_actions[i]
              writeln_flush(
                  "--> Running role `", role_args.name,
                  "' post-deploy action ", i, ":, ", action.tool, "...")

              assert(
                  action_handlers[action.tool],
                  "unknown tool"
                )(manifest, cluster_info, param, machine, role_args, action)
            end
          end

          writeln_flush(
              "--> Done post-deploying role `", role_args.name,
              "' to `", machine.name, "'..."
            )
        end
      end

      writeln_flush(
          "---> DONE POST-DEPLOY ON `", machine.name,
          "' from `", cluster_info.name, "'..."
        )
    end

    writeln_flush("----> DONE DEPLOYING TO `", cluster_info.name, "'...")
  end
end

--------------------------------------------------------------------------------

return
{
  deploy_to_cluster = deploy_to_cluster;
}
