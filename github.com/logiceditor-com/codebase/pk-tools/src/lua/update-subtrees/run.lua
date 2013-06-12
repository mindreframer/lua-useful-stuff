--------------------------------------------------------------------------------
-- run.lua: update-subtrees subtree manager
-- This file is a part of pk-tools library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------

local log, dbg, spam, log_error
      = import 'pk-core/log.lua' { 'make_loggers' } (
          "update-subtrees", "UST"
        )

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

local make_checker
      = import 'lua-nucleo/checker.lua'
      {
        'make_checker'
      }

local git_load_config,
      git_config_get_remote_url,
      git_remote_add,
      git_init_subtree,
      git_pull_subtree,
      git_update_index,
      git_is_dirty,
      git_has_untracked_files,
      git_get_tracking_branch_name_of_HEAD,
      git_are_branches_different,
      git_read,
      git_exec
      = import 'lua-aplicado/shell/git.lua'
      {
        'git_load_config',
        'git_config_get_remote_url',
        'git_remote_add',
        'git_init_subtree',
        'git_pull_subtree',
        'git_update_index',
        'git_is_dirty',
        'git_has_untracked_files',
        'git_get_tracking_branch_name_of_HEAD',
        'git_are_branches_different',
        'git_read',
        'git_exec'
      }

local load_project_manifest
      = import 'pk-tools/project_manifest.lua'
      {
        'load_project_manifest'
      }

local load_tools_cli_config,
      freeform_table_value
      = import 'pk-core/tools_cli_config.lua'
      {
        'load_tools_cli_config',
        'freeform_table_value'
      }

local create_config_schema
      = import 'update-subtrees/project-config/schema.lua'
      {
        'create_config_schema',
      }

--------------------------------------------------------------------------------

local ACTIONS = { }

local SCHEMA = create_config_schema()

local CONFIG, ARGS

local EXTRA_HELP = [[

update-subtrees: automated Git subtree update script

Usage:

    update-subtrees update [subtree-name] [options]

Options:

    --subtree-name        Update only specified subtree, skip others.

    --feature-branch      Update all subtrees from a given feature-branch
                          instead of a default one. Warning: use with caution!

Example:

    update-subtrees update

]]

--------------------------------------------------------------------------------

ACTIONS.update = function()
  local param = freeform_table_value(CONFIG.update_config.action.param)
  local manifest_path = param.manifest_path
  local subtree_name = param.subtree_name
  local branch_name = param.branch_name

  local manifest = load_project_manifest(
        manifest_path,
        CONFIG.PROJECT_PATH,
        "UNKNOWN_CLUSTER" -- irrelevant to this tool
      )

  local subtrees = assert(manifest.subtrees, "manifest subtrees are missing")

  local git_configs = setmetatable(
      { },
      {
        __index = function(t, path)
          -- TODO: ?! Does this belong here?
          do
            local checker = make_checker()

            git_update_index(path)

            checker:ensure(
                "must have clean working copy (hint: do commit or reset)",
                not git_is_dirty(path)
              )

            checker:ensure(
                "must have no untracked files (hint: commit or delete them)",
                not git_has_untracked_files(path)
              )

            -- Note no tracking branch check.

            assert(checker:result())
          end

          local v = git_load_config(path)
          t[path] = v
          return v
        end;
      }
    )

  for i = 1, #subtrees do
    local subtree = subtrees[i]

    local git_dir = assert(subtree.git, "project path is not set")
    local git_remote_name = assert(subtree.name, "subtree name is not set")
    local git_remote_url = assert(subtree.url, "subtree remote url is not set")
    local subtree_path = assert(subtree.path, "subtree path is not set")
    local branch_to_update

    if branch_name then
      local reply = git_read(
          git_dir, 'ls-remote', "--heads", git_remote_url, branch_name
        )
      local remote_branch_exists = reply and reply ~= ""
      if remote_branch_exists then
        branch_to_update = branch_name
      else
        branch_to_update = assert(subtree.branch, "subtree branch is not set")
      end
    else
      branch_to_update = assert(subtree.branch, "subtree branch is not set")
    end

    if subtree_name and git_remote_name ~= subtree_name then
      log("skipping", git_remote_name)
    else
      log("checking", git_remote_name)

      local git_config = git_configs[git_dir]

      local actual_remote_url = git_config_get_remote_url(
          git_config,
          git_remote_name
        )

      -- TODO: Check branch as well!

      if actual_remote_url ~= git_remote_url then
        if actual_remote_url then
          error("subtree " .. git_remote_name .. " url is outdated")
        end

        if lfs.attributes(git_dir.."/"..subtree_path) then
          log("initializing remote", git_remote_name, "not initializing subtree in" ,subtree_path)
          git_remote_add(git_dir, git_remote_name, git_remote_url, true) -- With fetch
        else
          log("initializing subtree", git_remote_name, "in", subtree_path)

          git_init_subtree(
              git_dir,
              git_remote_name,
              git_remote_url,
              branch_to_update,
              subtree_path,
              "merged " .. git_remote_name .. " as a subtree to " .. subtree_path,
              false -- Not interactive
            )

          log("pruning git repo ", git_remote_name, " in ", git_dir)
          git_exec(git_dir, 'remote', 'prune', git_remote_name)
        end
      else
        log("pulling subtree", git_remote_name)

        git_pull_subtree(
            git_dir,
            git_remote_name,
            branch_to_update
          )

        log("pruning git repo ", git_remote_name, " in ", git_dir)
        git_exec(git_dir, 'remote', 'prune', git_remote_name)
      end
    end
  end

  log("OK")
end

--------------------------------------------------------------------------------

local run = function(...)
  CONFIG, ARGS = assert(load_tools_cli_config(
      function(args)
        return
        {
          -- Reading args by indices was left for compatibility
          -- with update-subtrees scripts.
          PROJECT_PATH = args["--root"] or args[1];
          ["update_config"] =
          {
            action =
            {
              name = args["--action"] or args[3];
              param =
              {
                manifest_path = args["--manifest-path"] or args[2];
                subtree_name = args["--subtree-name"] or args[4];
                branch_name = args["--feature-branch"];
              };
            };
          }
        }
      end,
      EXTRA_HELP,
      SCHEMA,
      nil,
      nil,
      ...
    ))

  assert(ACTIONS[CONFIG.update_config.action.name], "unknown action")()
end
--------------------------------------------------------------------------------

return
{
  run = run;
}
