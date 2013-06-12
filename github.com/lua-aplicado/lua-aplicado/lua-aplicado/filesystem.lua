--------------------------------------------------------------------------------
-- filesystem.lua: basic code to work with files and directories
-- This file is a part of Lua-Aplicado library
-- Copyright (c) Lua-Aplicado authors (see file `COPYRIGHT` for the license)
--------------------------------------------------------------------------------

require 'posix'

local package = package
local loadfile, loadstring = loadfile, loadstring
local table_sort = table.sort
local debug_traceback = debug.traceback
local posix_unlink, posix_rmdir, posix_files, posix_mkdtemp =
      posix.unlink, posix.rmdir, posix.files, posix.mkdtemp

--------------------------------------------------------------------------------

-- TODO: Use debug.traceback() in do_atomic_op_with_file()?

local lfs = require 'lfs'

--------------------------------------------------------------------------------

local arguments,
      optional_arguments,
      method_arguments,
      eat_true
      = import 'lua-nucleo/args.lua'
      {
        'arguments',
        'optional_arguments',
        'method_arguments',
        'eat_true'
      }

local split_by_char,
      fill_curly_placeholders
      = import 'lua-nucleo/string.lua'
      {
        'split_by_char',
        'fill_curly_placeholders'
      }

local make_checker
      = import 'lua-nucleo/checker.lua'
      {
        'make_checker'
      }

local PATH_SEPARATOR = package.config:sub(1,1)
local IS_WINDOWS = (PATH_SEPARATOR == '\\')
local CURRENT_DIR = "."
local PARENT_DIR = ".."
local DEFAULT_TMP_DIR = "/tmp"
local DEFAULT_MKTEMP_MASK = "XXXXXX"

--------------------------------------------------------------------------------

local function find_all_files(path, regexp, dest, mode)
  dest = dest or {}
  mode = mode or false

  assert(mode ~= "directory")

  for filename in lfs.dir(path) do
    if filename ~= "." and filename ~= ".." then
      local filepath = path .. "/" .. filename
      local attr = lfs.attributes(filepath)

      if not attr then
        error("bad file attributes: " .. filepath)
        return nil, "bad file attributes: " .. filepath
      end

      if attr.mode == "directory" then
        local res, err = find_all_files(filepath, regexp, dest)
        if not res then
          return res, err
        end
      elseif not mode or attr.mode == mode then
        if filename:find(regexp) then
          dest[#dest + 1] = filepath
          -- print("found", filepath)
        end
      end
    end
  end

  return dest
end

local write_file = function(filename, new_data)
  arguments(
      "string", filename,
      "string", new_data
    )

  local file, err = io.open(filename, "w")
  if not file then
    return nil, err
  end

  file:write(new_data)
  file:close()
  file = nil

  return true
end

local read_file = function(filename)
  arguments(
      "string", filename
    )

  local file, err = io.open(filename, "r")
  if not file then
    return nil, err
  end

  local data = file:read("*a")
  file:close()
  file = nil

  return data
end

-- WARNING: Not atomic.
-- Returns "skipped" if data was not changed
local update_file = function(out_filename, new_data, force)
  arguments(
      "string", out_filename,
      "string", new_data,
      "boolean", force
    )

  local skip = false
  if lfs.attributes(out_filename, "mode") then
    local old_data, err = read_file(out_filename)
    if not old_data then
      return nil, err
    end

    skip = (old_data == new_data)
    if not skip and not force then
      return
        nil,
        "data is changed, refusing to override `" .. out_filename .. "'"
    end
  end

  if not skip then
    local res, err = write_file(out_filename, new_data)
    if not res then
      return nil, err
    end

    return true
  end

  return "skipped" -- Not changed
end

--------------------------------------------------------------------------------

local create_path_to_file = function(filename)
  arguments(
      "string", filename
    )

  local path = false
  local dirs = split_by_char(filename, "/")
  for i = 1, #dirs - 1 do
    path = path and (path .. "/" .. dirs[i]) or (dirs[i])
    if path ~= "" and not lfs.attributes(path) then
      local res, err = lfs.mkdir(path)
      if not res then
        return nil, "failed to create directory `" .. path .. "': " .. err
      end
    end
  end

  return true
end

--------------------------------------------------------------------------------

-- do primary operation on file with file lock
local do_atomic_op_with_file = function(filename, action, ...)
  arguments(
      "string",   filename,
      "function", action
    )

  local res, err

  local file, err = io.open(filename, "r+")
  if not file then
    return nil, "do_atomic_op_with_file, open fails: " .. err
  end

  -- TODO: Very unsafe? Endless loop may occur?
  while not lfs.lock(file, "w") do end

  local err_handler = function(msg)
    debug_traceback(msg, 3)
    return msg
  end

  -- TODO: Do xpcall() instead of pcall()?
  local status
  status, res, err = xpcall(action(file, ...), err_handler)
  if not status or not res then
    lfs.unlock(file)
    if not status then
      err = res
    end
    return nil, "do_atomic_op_with_file, pcall fails: " .. err
  end

  res, err = lfs.unlock(file)
  if not res then
    file:close()
    file = nil
    return nil, "do_atomic_op_with_file, unlock fails: " .. err
  end

  file:close()
  file = nil
  return true
end

--------------------------------------------------------------------------------

local load_all_files = function(dir_name, pattern)
  arguments(
      "string", dir_name,
      "string", pattern
    )

  local files = find_all_files(dir_name, pattern)
  if #files == 0 then
    return nil, "no files found in " .. dir_name
  end

  table_sort(files) -- Sort filenames for predictable order.

  local chunks = { }

  for i = 1, #files do
    local chunk, err = loadfile(files[i])

    if not chunk then
      return nil, err
    end

    chunks[#chunks + 1] = chunk
  end

  return chunks
end

--------------------------------------------------------------------------------

local load_all_files_with_curly_placeholders = function(
    dir_name,
    pattern,
    dictionary
  )
  arguments(
      "string", dir_name,
      "string", pattern,
      "table", dictionary
    )

  local filenames = find_all_files(dir_name, pattern)
  if #filenames == 0 then
    return nil, "no files found in " .. dir_name
  end

  table_sort(filenames) -- Sort filenames for predictable order.

  local chunks = { }

  for i = 1, #filenames do
    local filename = filenames[i]

    local str, err = read_file(filename)
    if not str then
      return nil, err
    end

    str = fill_curly_placeholders(str, dictionary)

    local chunk, err = loadstring(str, "=" .. filename)
    if not chunk then
      return nil, err
    end

    chunks[#chunks + 1] = chunk
  end

  return chunks
end

local is_directory = function(path)
  local mode, err = lfs.attributes(path, 'mode')
  if not mode then
    return nil, err
  end

  return (mode == "directory")
end

local does_file_exist = function(filename)
  return not not lfs.attributes(filename)
end

-- From penlight (modified)
--- given a path, return the directory part and a file part.
-- if there's no directory part, the first value will be empty
-- @param path A file path
local function splitpath(path)
  local i = #path
  local ch = path:sub(i, i)
  while i > 0 and ch ~= "/" do
    i = i - 1
    ch = path:sub(i, i)
  end
  if i == 0 then
    return '', path
  else
    return path:sub(1, i - 1), path:sub(i + 1)
  end
end

local get_filename_from_path = function(path)
  local dirname, filename = splitpath(path)
  return filename
end

-- From penlight (modified)
-- Inspired by path.extension
local get_extension = function(path)
  local i = #path
  local ch = path:sub(i, i)
  while i > 0 and ch ~= '.' do
    i = i - 1
    ch = path:sub(i, i)
  end
  if i == 0 then
    return ''
  else
    return path:sub(i + 1)
  end
end

-- Inspired by path.join from MIT-licensed Penlight
-- https://github.com/stevedonovan/Penlight
--- Return the path resulting from combining the individual paths.
-- @param path1 A file path
-- @param path2 A file path
-- @param ... more file paths
local function join_path(path1, path2, ...)
  arguments(
      "string", path1,
      "string", path2
    )

  if select('#', ...) > 0 then
    return join_path(join_path(path1, path2), ...)
  end

  if
    path1:sub(#path1, #path1) ~= PATH_SEPARATOR and
    path2:sub(1, 1) ~= PATH_SEPARATOR
  then
      path1 = path1 .. PATH_SEPARATOR
  end

  return path1 .. path2
end

-- Inspired by path.normpath from MIT-licensed Penlight
-- https://github.com/stevedonovan/Penlight
--  A//B, A/./B and A/foo/../B all become A/B.
-- @param path a file path
local function normalize_path(path)
  arguments(
      "string", path
    )

  if IS_WINDOWS then
    if path:match '^\\\\' then -- UNC
        return '\\\\' .. normalize_path(path:sub(3))
    end
    path = path:gsub('/','\\')
  end

  local k
  -- /./ -> / ; // -> /
  local pattern = PATH_SEPARATOR .. "+%.?" .. PATH_SEPARATOR
  repeat
    path, k = path:gsub(pattern, PATH_SEPARATOR)
  until k == 0

  -- A/../ -> (empty
  pattern = "[^" .. PATH_SEPARATOR .. "]+" .. PATH_SEPARATOR .. "%.%."
    .. PATH_SEPARATOR .. "?"
  repeat
      path, k = path:gsub(pattern,'')
  until k == 0

  if path == '' then path = '.' end
  return path
end

--- Removes a whole directory tree. Should work like rm -fr.
-- Warning: the implementation is not atomic.
-- Atomicity should be guaranteed by external means, if needed.
-- @param path_to_dir A directory path
local function rm_tree(path_to_dir)
  arguments(
      "string", path_to_dir
    )

  local checker = make_checker()

  if not is_directory(path_to_dir) then
    checker:ensure("unlink file", posix_unlink(path_to_dir))
    return checker:result()
  end

  for entry_name in posix_files(path_to_dir) do
    -- skip "." and ".." entries
    if entry_name ~= CURRENT_DIR and entry_name ~= PARENT_DIR then
      local entry_full_path = normalize_path(join_path(path_to_dir, entry_name))
      if is_directory(entry_full_path) then
        checker:ensure("remove tree", rm_tree(entry_full_path)) -- remove directory recursively
      else
        checker:ensure("unlink file", posix_unlink(entry_full_path)) -- remove files
      end
    end
  end
  --after all entries in the directory was deleted, delete the directory
  checker:ensure("remove empty dir", posix_rmdir(path_to_dir))

  return checker:result()
end

--- Convience function for creating temporary directories
-- @param tmpdir Path to directory for temporary files/directories
-- @param prefix Prefix used in pathname generation
-- @return path to created directory or nil
local create_temporary_directory = function(prefix, tmpdir)
  tmpdir = tmpdir or os.getenv("TMPDIR") or DEFAULT_TMP_DIR

  arguments(
      "string", tmpdir,
      "string", prefix
    )

  return posix_mkdtemp(join_path(tmpdir, prefix .. DEFAULT_MKTEMP_MASK))
end

-------------------------------------------------------------------------------

return
{
  find_all_files = find_all_files;
  write_file = write_file;
  read_file = read_file;
  update_file = update_file;
  create_path_to_file = create_path_to_file;
  do_atomic_op_with_file = do_atomic_op_with_file; -- do atomic operation
  load_all_files = load_all_files;
  load_all_files_with_curly_placeholders = load_all_files_with_curly_placeholders;
  is_directory = is_directory;
  does_file_exist = does_file_exist;
  splitpath = splitpath;
  get_filename_from_path = get_filename_from_path;
  get_extension = get_extension;
  join_path = join_path;
  normalize_path = normalize_path;
  rm_tree = rm_tree;
  create_temporary_directory = create_temporary_directory;
}
