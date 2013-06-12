--------------------------------------------------------------------------------
-- 0001-filesystem.lua: tests for file system
-- This file is a part of Lua-Aplicado library
-- Copyright (c) Lua-Aplicado authors (see file `COPYRIGHT` for the license)
--------------------------------------------------------------------------------

local socket = require 'socket'
require 'posix'
local posix_getpid, posix_strftime, posix_gmtime =
      posix.getpid, posix.strftime, posix.gmtime

--------------------------------------------------------------------------------

local arguments,
      method_arguments,
      optional_arguments
      = import 'lua-nucleo/args.lua'
      {
        'arguments',
        'method_arguments',
        'optional_arguments'
      }

local ensure,
      ensure_is,
      ensure_equals,
      ensure_strequals,
      ensure_tequals,
      ensure_error,
      ensure_aposteriori_probability,
      ensure_fails_with_substring
      = import 'lua-nucleo/ensure.lua'
      {
        'ensure',
        'ensure_is',
        'ensure_equals',
        'ensure_strequals',
        'ensure_tequals',
        'ensure_error',
        'ensure_aposteriori_probability',
        'ensure_fails_with_substring'
      }

local starts_with
      = import 'lua-nucleo/string.lua'
      {
        'starts_with'
      }

local assert_is_string
      = import 'lua-nucleo/typeassert.lua'
      {
        'assert_is_string'
      }

local find_all_files,
      write_file,
      read_file,
      update_file,
      create_path_to_file,
      do_atomic_op_with_file,
      join_path,
      normalize_path,
      rm_tree,
      does_file_exist,
      create_temporary_directory,
      get_filename_from_path,
      exports
      = import 'lua-aplicado/filesystem.lua'
      {
        'find_all_files',
        'write_file',
        'read_file',
        'update_file',
        'create_path_to_file',
        'do_atomic_op_with_file',
        'join_path',
        'normalize_path',
        'rm_tree',
        'does_file_exist',
        'create_temporary_directory',
        'get_filename_from_path'
      }


--------------------------------------------------------------------------------

local test = (...)("filesystem", exports)

--------------------------------------------------------------------------------

local register_temp_file
do
  local files_to_be_removed = {}

  register_temp_file = function(filename)
    os.remove(filename)
    files_to_be_removed[#files_to_be_removed + 1] = filename
    return filename
  end

  test:tear_down(function()
    for i = 1, #files_to_be_removed do
      os.remove(files_to_be_removed[i])
    end
  end)
end

-- Helper: Creates list of empty temporary files in temporary directory.
-- Returns path to temporary directory
local function create_tmp_files(filenames_table, tmp_dir)
  for _, filename in pairs(filenames_table) do
    local test_file_name = register_temp_file(join_path(tmp_dir, filename))
    create_path_to_file(test_file_name)
    write_file(test_file_name, "")
  end
end

--------------------------------------------------------------------------------

test:group 'do_atomic_op_with_file'

--------------------------------------------------------------------------------

-- TODO: broken, due do_with_server dependency
-- https://github.com/lua-aplicado/lua-aplicado/issues/11
test:BROKEN "update-file-from-2-threads" (function()
  local TEST_FILE_DO_ATOMIC = register_temp_file("./data/test_do_atomic")

  local make_callback = function(op_timeout, data)
    arguments(
      "number", op_timeout,
      "string", data
      )

    return function(file)
      socket.sleep(op_timeout)
      return file:write(data)
    end
  end

  local make_file_updater = function(start_timeout, op_timeout, data)
    arguments(
      "number", start_timeout,
      "number", op_timeout,
      "string", data
      )

    return function()
      socket.sleep(start_timeout)
      local res, err = do_atomic_op_with_file(TEST_FILE_DO_ATOMIC, make_callback(op_timeout, data))
      if not res then
        error("worker `" .. data .. "' failed: " .. err)
      end
    end
  end

  local make_file_updater_loops = function()
    local workers = {}

    workers[#workers + 1] = make_file_updater(0,  2, "(worker 1)")
    workers[#workers + 1] = make_file_updater(1,  0, "(worker 2)")

    return workers
  end

  local expected = "(worker 1)(worker 2)"

  do_with_servers(
      make_file_updater_loops(),
      function(pid_list)
        socket.sleep(3)
        local actual = read_file(TEST_FILE_DO_ATOMIC)
        ensure_strequals("file content after atomic ops", actual, expected)
      end
    )
end)

--------------------------------------------------------------------------------

test:test_for "join_path" (function()
  ensure_strequals(
    "regular joininig",
    join_path('A', 'B'),
    'A/B'
    )
  ensure_strequals(
    "multiple joininig",
    join_path('A', 'B', 'C', 'D'),
    'A/B/C/D'
    )
  ensure_strequals(
    "doesn't add extra slashes, if first path ends with slash",
    join_path('A/', 'B/'),
    'A/B/'
    )
  ensure_strequals(
    "doesn't add extra slashes, if second path begins with slash",
    join_path('/A', '/B'),
    '/A/B'
    )
  ensure_strequals(
    "joins 'as is', making no normalization: case /./",
    join_path('./A', './B'),
    './A/./B'
    )
  ensure_strequals(
    "joins 'as is', making no normalization: case /foo/..",
    join_path('A/foo/..', 'foo/../B'),
    'A/foo/../foo/../B'
    )
  ensure_strequals(
    "joins 'as is', making no normalization: case //",
    join_path('A//B/', '/C//D'),
    'A//B//C//D'
    )
end)

--------------------------------------------------------------------------------

test:tests_for "normalize_path"

test:case "normalize_slashes" (function()
  ensure_strequals(
    "normalize //",
    normalize_path('A//B'),
    'A/B'
    )
  ensure_strequals(
    "normalize // in any position",
    normalize_path('//A//B//'),
    '/A/B/'
    )
end)

test:case "normalize_empty_part_of_path" (function()
  ensure_strequals(
    "normalize /./",
    normalize_path('A/./B'),
    'A/B'
    )
  ensure_strequals(
    "normalize /foo/..",
    normalize_path('A/foo/../B'),
    'A/B'
    )
end)

--TODO: https://github.com/lua-aplicado/lua-aplicado/issues/8
test:BROKEN "normalize_empty_part_of_path_in_any_position" (function()
  ensure_strequals(
    "must remove './' in the beginning of a path too",
    normalize_path('./A/B'),
    'A/B'
    )
end)

--------------------------------------------------------------------------------

-- NOTE: Tests for rm_tree doesn't use ":with(tmpdir())" decorator,
--       because it uses rm_tree itself
test:tests_for "rm_tree"

local TEST_DIR = join_path(
    "/tmp",
    "lua-aplicado-0001-" .. posix_getpid("pid") .. "-" .. posix_strftime('%F-%T', posix_gmtime())
  )

test:case "rm_tree_without_params" (function()
  ensure_fails_with_substring(
      "rm_tree must fail if is called witout params",
      (function()
          rm_tree()
      end),
      "argument #1: expected `string'"
    )
end)

test:case "rm_tree_single_empty_dir" (function()
  -- note, that only path is created in this test-case
  create_path_to_file(join_path(TEST_DIR, "test_file"))

  rm_tree(TEST_DIR)
  ensure(
      "rm_tree deletes single empty directory",
      not does_file_exist(TEST_DIR)
    )
end)

test:case "rm_tree_single_dir_with_files" (function()
  create_tmp_files({ "test_file_1", "test_file_2" }, TEST_DIR)

  rm_tree(TEST_DIR)
  ensure(
      "rm_tree deletes single directory with files",
      not does_file_exist(TEST_DIR)
    )
end)

test:case "rm_tree_full_test" (function()
  local tmp_files_names =
  {
    "test_file_1";
    "1/test_file_1_1";
    "1/test_file_1_2";
    "1/1/test_file_1_1_1";
  }
  create_tmp_files(tmp_files_names, TEST_DIR)

  rm_tree(TEST_DIR)
  ensure(
      "rm_tree full test",
      not does_file_exist(TEST_DIR)
    )
end)

--------------------------------------------------------------------------------

test:tests_for "create_temporary_directory"

test:case "create_temporary_directory_works" (function()
  local prefix = "test-tmpdir"

  -- prepare sandbox
  -- TODO: https://github.com/lua-aplicado/lua-aplicado/issues/17
  --       Write create_path, and avoid this hack with `join_path`
  create_path_to_file(join_path(TEST_DIR, "dummy"))

  local tmpdir = create_temporary_directory(prefix, TEST_DIR)

  ensure_is("create_temporary_directory returns string", tmpdir, "string")
  ensure(
      "create_temporary_directory returns directory",
      does_file_exist(tmpdir)
    )
  ensure(
      "created directory name starts with required prefix",
      starts_with(get_filename_from_path(tmpdir), prefix)
    )

  rm_tree(TEST_DIR)

  -- ensure our temporary dirs was cleaned up
  ensure(
      "rm_tree deletes single directory with files",
      not does_file_exist(TEST_DIR)
    )
end)

--------------------------------------------------------------------------------

test:UNTESTED "find_all_files"
test:UNTESTED "write_file"
test:UNTESTED "read_file"
test:UNTESTED "update_file"
test:UNTESTED "create_path_to_file"
test:UNTESTED "load_all_files"
test:UNTESTED "does_file_exist"
test:UNTESTED "is_directory"
test:UNTESTED "load_all_files_with_curly_placeholders"
test:UNTESTED "get_filename_from_path"
test:UNTESTED "get_extension"
test:UNTESTED "splitpath"

--------------------------------------------------------------------------------

-- TODO: Add more tests on do_atomic_op_with_file()
-- https://github.com/lua-aplicado/lua-aplicado/issues/10
