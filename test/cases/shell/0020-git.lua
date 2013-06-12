--------------------------------------------------------------------------------
-- 0020-git.lua: tests for shell git library
-- This file is a part of Lua-Aplicado library
-- Copyright (c) Lua-Aplicado authors (see file `COPYRIGHT` for the license)
--------------------------------------------------------------------------------

local pairs
    = pairs

local git_init,
      git_init_bare,
      git_add_directory,
      git_commit_with_message,
      git_clone,
      git_add_path,
      git_get_list_of_staged_files,
      git_get_current_branch_name,
      git_get_branch_list,
      git_create_branch,
      git_checkout,
      git_init_subtree,
      git_pull_subtree,
      git_exports
      = import 'lua-aplicado/shell/git.lua'
      {
        'git_init',
        'git_init_bare',
        'git_add_directory',
        'git_commit_with_message',
        'git_clone',
        'git_add_path',
        'git_get_list_of_staged_files',
        'git_get_current_branch_name',
        'git_get_branch_list',
        'git_create_branch',
        'git_checkout',
        'git_init_subtree',
        'git_pull_subtree'
      }

local ensure,
      ensure_equals,
      ensure_strequals,
      ensure_error,
      ensure_fails_with_substring,
      ensure_tequals
      = import 'lua-nucleo/ensure.lua'
      {
        'ensure',
        'ensure_equals',
        'ensure_strequals',
        'ensure_error',
        'ensure_fails_with_substring',
        'ensure_tequals'
      }

local tifindvalue_nonrecursive
      = import 'lua-nucleo/table.lua'
      {
        'tifindvalue_nonrecursive'
      }

local starts_with
      = import 'lua-nucleo/string.lua'
      {
        'starts_with'
      }

local arguments
      = import 'lua-nucleo/args.lua'
      {
        'arguments'
      }

local temporary_directory
      = import 'lua-aplicado/testing/decorators.lua'
      {
        'temporary_directory'
      }

local read_file,
      write_file,
      join_path,
      create_path_to_file
      = import 'lua-aplicado/filesystem.lua'
      {
        'read_file',
        'write_file',
        'join_path',
        'create_path_to_file'
      }

local commit_content,
      create_repo_with_content
      = import 'pk-test/testing/git.lua'
      {
        'commit_content',
        'create_repo_with_content'
      }

local test = (...)("git", git_exports)

local PROJECT_NAME = "lua-aplicado"

--------------------------------------------------------------------------------
-- TODO: cover with tests all shell/git.lua
-- https://github.com/lua-aplicado/lua-aplicado/issues/18

test:test_for "git_init"
  :with(temporary_directory("tmp_dir", PROJECT_NAME)) (
function(env)
  git_init(env.tmp_dir)
  ensure_equals(
      "git HEAD file content must match expected",
      read_file(join_path(env.tmp_dir, ".git", "HEAD")),
      "ref: refs/heads/master\n"
    )
end)

test:test_for "git_init_bare"
  :with(temporary_directory("tmp_dir", PROJECT_NAME)) (
function(env)
  git_init_bare(env.tmp_dir)
  ensure_equals(
      "git HEAD file content must match expected",
      read_file(join_path(env.tmp_dir, "HEAD")),
      "ref: refs/heads/master\n"
    )
end)

test:test_for "git_clone"
  :with(temporary_directory("source_dir", PROJECT_NAME))
  :with(temporary_directory("destination_dir", PROJECT_NAME)) (
function(env)
  local test_filename = "testfile"
  local test_data = "test data"

  create_repo_with_content(
      env.source_dir,
      {
        [test_filename] = test_data;
      },
      "initial commit"
    )

  git_clone(env.destination_dir, env.source_dir)

  ensure_equals(
      "data in testfile must match committed in source directory",
      read_file(join_path(env.destination_dir, test_filename)),
      test_data
    )
end)

test:tests_for "git_add_path" "git_get_list_of_staged_files"
test:case "git_add_path_and_git_get_list_of_staged_files"
  :with(temporary_directory("tmp_dir", PROJECT_NAME)) (
function(env)
  create_repo_with_content(
      env.tmp_dir,
      {
        ["testfile1"] = "test data";
        ["testfile2"] = "test data";
        ["testfile3"] = "test data";
      },
      "initial commit"
    )

  git_add_path(env.tmp_dir, "testfile1")
  git_add_path(env.tmp_dir, "testfile2")
  git_add_path(env.tmp_dir, "testfile3")

  ensure_tequals(
      "staged filelist must equals expected",
      git_get_list_of_staged_files(env.tmp_dir),
      {
        "testfile1";
        "testfile2";
        "testfile3";
      }
    )
end)

test:test_for "git_get_current_branch_name"
  :with(temporary_directory("tmp_dir", PROJECT_NAME)) (
function(env)
  create_repo_with_content(
      env.tmp_dir,
      {
        ["testfile"] = "test data";
      },
      "initial commit"
    )

  ensure_equals(
      "branch name must equals master",
      git_get_current_branch_name(env.tmp_dir),
      "master"
    )
end)

test:test_for "git_create_branch"
  :with(temporary_directory("tmp_dir", PROJECT_NAME)) (
function(env)
  create_repo_with_content(
      env.tmp_dir,
      {
        ["testfile"] = "test data";
      },
      "initial commit"
    )

  git_create_branch(env.tmp_dir, "test_branch", "master", true)

  ensure_equals(
      "branch name must equals test_branch",
      git_get_current_branch_name(env.tmp_dir),
      "test_branch"
    )

  git_create_branch(env.tmp_dir, "test_branch2")
  ensure(
      "branch name test_branch2 must exist in branch list",
      tifindvalue_nonrecursive(
          git_get_branch_list(env.tmp_dir),
          "test_branch2"
        )
    )
end)

test:test_for "git_get_branch_list"
  :with(temporary_directory("tmp_dir", PROJECT_NAME)) (
function(env)
  create_repo_with_content(
      env.tmp_dir,
      {
        ["testfile"] = "test data";
      },
      "initial commit"
    )

  git_create_branch(env.tmp_dir, "test_branch1")
  git_create_branch(env.tmp_dir, "test_branch2")

  ensure_tequals(
      "branch list must equals expected",
      git_get_branch_list(env.tmp_dir),
      {
        "master";
        "test_branch1";
        "test_branch2";
      }
    )
end)

test:test_for "git_checkout"
  :with(temporary_directory("tmp_dir", PROJECT_NAME)) (
function(env)
  create_repo_with_content(
      env.tmp_dir,
      {
        ["testfile"] = "test data";
      },
      "initial commit"
    )

  local test_branchname = "test_branch"

  git_create_branch(env.tmp_dir, test_branchname)
  git_checkout(env.tmp_dir, test_branchname)

  ensure_equals(
      "branch name must equals master",
      git_get_current_branch_name(env.tmp_dir),
      test_branchname
    )
end)

test:test_for "git_pull_subtree"
  :with(temporary_directory("subproject_dir", PROJECT_NAME))
  :with(temporary_directory("end_project_dir", PROJECT_NAME))
  :with(temporary_directory("destination_dir", PROJECT_NAME)) (
function(env)
  local subproject_test_filename = "subtestfile"
  local subproject_test_filename2 = "subtestfile2"
  local end_project_test_filename = "testfile"
  local test_data = "test data"
  local changed_test_data = "changed test data"
  local subtree_name = "test-subtree"
  local lib_path = join_path("lib", subtree_name)

  create_repo_with_content(
      env.subproject_dir,
      {
        [subproject_test_filename] = test_data;
      },
      "initial commit in subporject"
    )

  create_repo_with_content(
      env.end_project_dir,
      {
        [end_project_test_filename] = test_data;
      },
      "initial commit in end porject"
    )

  git_clone(env.destination_dir, env.end_project_dir)

  git_init_subtree(
      env.destination_dir,
      subtree_name,
      env.subproject_dir,
      "master",
      lib_path,
      "init subtree"
    )

  commit_content(
      env.subproject_dir,
      {
        [subproject_test_filename] = changed_test_data;
      },
      "changes made"
    )

  local pull_subtree = function(branch)
    branch = branch or "master"
    git_pull_subtree(
        env.destination_dir,
        "test-subtree",
        branch,
        lib_path,
        "merge commit message"
      )
  end

  -- simple pull subtree check

  pull_subtree()

  ensure_equals(
      "data in testfile must match committed in subtree directory",
      read_file(join_path(
          env.destination_dir,
          lib_path,
          subproject_test_filename
        )),
      changed_test_data
    )

  -- new file pull subtree check

  commit_content(
      env.subproject_dir,
      {
        [subproject_test_filename2] = test_data;
      },
      "add new file"
    )

  pull_subtree()

  ensure_equals(
      "data in testfile must match committed in subtree directory",
      read_file(join_path(
          env.destination_dir,
          lib_path,
          subproject_test_filename2
        )),
      test_data
    )

  -- merge pull subtree check - in repo first

  local first_branchname = "first_branch"
  local second_branchname = "second_branch"
  local first_data = "older data\n"
  local second_data = "newer data\n"

  git_create_branch(
      env.subproject_dir,
      first_branchname,
      "master",
      true
    )

  commit_content(
      env.subproject_dir,
      {
        [subproject_test_filename] = first_data;
      },
      "older commit"
    )

  git_create_branch(
      env.subproject_dir,
      second_branchname,
      "master",
      true
    )

  commit_content(
      env.subproject_dir,
      {
        [subproject_test_filename] = second_data;
      },
      "newer commit"
    )

  git_create_branch(
      env.destination_dir,
      "first_then_second_test",
      "master",
      true
    )
  pull_subtree(first_branchname)
  pull_subtree(second_branchname)

  ensure_equals(
      "data in testfile must match committed later",
      read_file(join_path(
          env.destination_dir,
          lib_path,
          subproject_test_filename
        )),
      second_data
    )
end)

--------------------------------------------------------------------------------

test:UNTESTED "git_format_command"
test:UNTESTED "git_exec"
test:UNTESTED "git_read"
test:UNTESTED "git_get_tracking_branch_name_of_HEAD"
test:UNTESTED "git_update_index"
test:UNTESTED "git_is_dirty"
test:UNTESTED "git_has_untracked_files"
test:UNTESTED "git_are_branches_different"
test:UNTESTED "git_is_file_changed_between_revisions"
test:UNTESTED "git_add_directory"
test:UNTESTED "git_commit_with_editable_message"
test:UNTESTED "git_commit_with_message"
test:UNTESTED "git_push_all"
test:UNTESTED "git_is_directory_dirty"
test:UNTESTED "git_load_config"
test:UNTESTED "git_config_get_remote_url"
test:UNTESTED "git_remote_rm"
test:UNTESTED "git_remote_add"
test:UNTESTED "git_init_subtree"
