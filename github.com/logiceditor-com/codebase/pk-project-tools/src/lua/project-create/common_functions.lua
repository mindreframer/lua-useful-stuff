--------------------------------------------------------------------------------
-- common_functions.lua: project-create common functions
-- This file is a part of pk-project-tools library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------

local loadfile, loadstring = loadfile, loadstring

--------------------------------------------------------------------------------

local log, dbg, spam, log_error
      = import 'pk-core/log.lua' { 'make_loggers' } (
          "project-create/common_functions", "PCC"
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

local is_table,
      is_function,
      is_string,
      is_number
      = import 'lua-nucleo/type.lua'
      {
        'is_table',
        'is_function',
        'is_string',
        'is_number'
      }

local tgetpath,
      tclone,
      twithdefaults,
      tset,
      tiflip,
      empty_table
      = import 'lua-nucleo/table-utils.lua'
      {
        'tgetpath',
        'tclone',
        'twithdefaults',
        'tset',
        'tiflip',
        'empty_table'
      }

local ordered_pairs
      = import 'lua-nucleo/tdeepequals.lua'
      {
        'ordered_pairs'
      }

local load_project_manifest
      = import 'pk-tools/project_manifest.lua'
      {
        'load_project_manifest'
      }

local split_by_char,
      escape_lua_pattern
      = import 'lua-nucleo/string.lua'
      {
        'split_by_char',
        'escape_lua_pattern'
      }

local load_all_files,
      write_file,
      read_file,
      find_all_files,
      is_directory,
      does_file_exist,
      write_file,
      read_file,
      create_path_to_file
      = import 'lua-aplicado/filesystem.lua'
      {
        'load_all_files',
        'write_file',
        'read_file',
        'find_all_files',
        'is_directory',
        'does_file_exist',
        'write_file',
        'read_file',
        'create_path_to_file'
      }

--------------------------------------------------------------------------------

-- TODO: until manual log level will be available #3775
dbg = function() end
spam = function() end

--------------------------------------------------------------------------------

local function unify_manifest_dictionary(dictionary)
  arguments(
      "table", dictionary
    )
  for k, v in ordered_pairs(dictionary) do
    if is_table(v) then
      --check all values where key is number
      local i = 1
      while v[i] ~= nil do
        if is_table(v[i]) then
          if v[i].name ~= nil then
            local name = v[i].name
            v[name] = { }
            for k_local, v_local in ordered_pairs(v[i]) do
              if k_local ~= "name" then
                v[name][k_local] = v[i][k_local]
                v[i][k_local] = nil
              end
            end
            v[i] = name
          end
        end
        i = i + 1
      end
      v = unify_manifest_dictionary(v)
    end
  end
  return dictionary
end

--------------------------------------------------------------------------------

local find_data_using_parents = function(manifest, table_name, key, replaces_used)
  arguments(
      "table", manifest,
      "string", table_name,
      "string", key
    )
  optional_arguments(
      "table", replaces_used
    )
  local check_level = manifest

  local found = false
  while not found do
    if replaces_used then
      for k, v in ordered_pairs(replaces_used) do
        local value = tgetpath(check_level, "subdictionary", v, table_name, key)
        if value then
          return value
        end
      end
    end

    if tgetpath(check_level, table_name, key) then
      found = true
    elseif check_level.parent then
      check_level = check_level.parent
    else
      break
    end
  end

  local value = tgetpath(check_level, table_name, key)
  if not value then
    dbg("WARNING!", key, "not found in table up to root")
    return nil, key .. " not found in table up to root"
  end

  return value
end

local find_replicate_data = function(manifest, name, fs_data)
  arguments(
      "table", manifest,
      "string", name
    )
  optional_arguments(
      "table", fs_data
    )
  dbg("Searching replicate data:", name)
  return find_data_using_parents(manifest, "replicate_data", name, fs_data)
end

local find_dictionary_data = function(manifest, name, fs_data)
  arguments(
      "table", manifest,
      "string", name
    )
  optional_arguments(
      "table", fs_data
    )
  dbg("Searching dictionary data:", name)
  return find_data_using_parents(manifest, "dictionary", name, fs_data)
end

--------------------------------------------------------------------------------

local get_wrapped_string = function(string_to_process, wrapper)
  arguments(
      "string", string_to_process,
      "table", wrapper
    )

  local block_top_wrapper =
    escape_lua_pattern(wrapper.top.left) .. string_to_process ..
    escape_lua_pattern(wrapper.top.right)
  local block_bottom_wrapper =
    escape_lua_pattern(wrapper.bottom.left) .. string_to_process ..
    escape_lua_pattern(wrapper.bottom.right)
  return
    block_top_wrapper .. ".-" .. block_bottom_wrapper,
    block_top_wrapper,
    block_bottom_wrapper
end

--------------------------------------------------------------------------------

local cut_wrappers = function(text, wrapper, value)
  arguments(
      "string", text,
      "table", wrapper,
      "string", value
    )
  local string_to_find, block_top_wrapper, block_bottom_wrapper =
    get_wrapped_string(value, wrapper)
  return text:gsub(block_top_wrapper .. "\n", ""):gsub("\n" .. block_bottom_wrapper, "")
end

local remove_wrappers = function(text, wrapper)
  arguments(
      "string", text,
      "table", wrapper
    )
  return cut_wrappers(text, wrapper, '[^{}]-')
end

--------------------------------------------------------------------------------

local function find_wrapped_values(text, wrapper, values)
  values = values or { }
  arguments(
      "string", text,
      "table", wrapper,
      "table", values
    )
  local wrapper_left_start, wrapper_left_end = text:find(wrapper.left, nil, true)

  if wrapper_left_end then
    local wrapper_right_start, wrapper_right_end =
      text:sub(wrapper_left_end + 1):find(wrapper.right, nil, true)

    if wrapper_right_start then
      local val = text:sub(wrapper_left_end + 1, wrapper_left_end + wrapper_right_start - 1)
      if #val > 0 then
        values[#values + 1] = val;
      end
      find_wrapped_values(
          text:sub(wrapper_left_end + wrapper_right_end + 1),
          wrapper,
          values
        )
    else
      dbg("found string with single left wrapper:", text, "wrapper:", wrapper)
    end
  end
  spam("for", text, "values found:", values, "wrapper used:", wrapper)
  return values
end

--------------------------------------------------------------------------------

local function find_top_level_blocks(text, wrapper, replaces_used, blocks)
  blocks = blocks or { }
  arguments(
      "string", text,
      "table", wrapper,
      "table", blocks
    )
  optional_arguments(
      "table", replaces_used
    )
  if replaces_used then
    for k, v in ordered_pairs(replaces_used) do
      text = cut_wrappers(text, wrapper, k)
    end
  end

  local top_wrapper_start, top_left_wrapper_end = text:find(wrapper.top.left, nil, true)
  if top_left_wrapper_end then
    local top_right_wrapper_start =
      text:sub(top_left_wrapper_end + 1):find(wrapper.top.right, nil, true) +
      top_left_wrapper_end
    if not top_right_wrapper_start then
      log_error(
          "text:", text,
          "text part:", text:sub(top_left_wrapper_end + 1),
          "warppers found:", top_wrapper_start, top_left_wrapper_end
        )
      return error("matching block not found")
    end

    local val = text:sub(top_left_wrapper_end + 1, top_right_wrapper_start - 1)
    local _, bottom_wrapper_end =
      text:find(wrapper.bottom.left .. val .. wrapper.bottom.right, nil, true)
    if not bottom_wrapper_end then
      log_error(
          "text:", text,
          "val:", val,
          "matching block start:",
          text:sub(top_left_wrapper_end + 1, top_right_wrapper_start - 1),
          "warppers found:", top_left_wrapper_end, top_right_wrapper_start
        )
      return error("matching block not found")
    end
    blocks[#blocks + 1] =
    {
      value = val;
      text = text:sub(top_wrapper_start, bottom_wrapper_end + 1);
    }
    find_top_level_blocks(
        text:sub(bottom_wrapper_end + 1),
        wrapper,
        replaces_used,
        blocks
      )
  end
  return blocks
end

--------------------------------------------------------------------------------

local get_template_path = function(name, paths)
  arguments(
      "string", name,
      "table", paths
    )
  for i = 1, #paths do
    local path = paths[i].path .. "/" .. name .. ".template"
    if does_file_exist(path) then
      return path
    end
  end
  error("Template " .. name .. " not found in paths: " .. tstr(paths))
end

local function get_template_paths(template_name, template_paths, templates)
  templates = templates or { }
  arguments(
      "string", template_name,
      "table", template_paths,
      "table", templates
    )
  local path = get_template_path(template_name, template_paths)
  templates[#templates + 1] = path

  dbg("Template path:", path)
  local config_path = path .. "/template_config"
  if does_file_exist(config_path) then
    dbg("Template config:", config_path)
    local template_metamanifest = load_project_manifest(config_path, "", "")
    for i = 1, #template_metamanifest.parent_templates do
      get_template_paths(
          template_metamanifest.parent_templates[i].name,
          template_paths,
          templates
        )
    end
  else
    dbg("No template config found for", template_name, "template")
  end
  return templates
end

--------------------------------------------------------------------------------

local function make_plain_dictionary(dictionary, parent)
  arguments(
      "table", dictionary
    )
  optional_arguments(
      "table", parent
    )
  local replicate_data = { }
  local processed = { }
  local subdictionary = { }

  for k, v in ordered_pairs(dictionary) do
    if is_table(v) then
      replicate_data[#replicate_data + 1] = k
    elseif v == false then
      replicate_data[#replicate_data + 1] = k
    end
  end

  for i = 1, #replicate_data do
    local data = replicate_data[i]
    local replicate = dictionary[data]
    replicate_data[data] = { }
    if is_table(replicate) then
      for j = 1, #replicate do
        local name = data:sub(1, -2) .. "_" .. string.format("%03d", j)
        dictionary[name] = replicate[j]
        replicate_data[data][j] = name
        subdictionary[name] = replicate[replicate[j]]
        if is_table(subdictionary[name]) then
          subdictionary[name] = make_plain_dictionary(
              subdictionary[name],
              dictionary
            )
        end
      end
      processed[data] = tclone(dictionary[data])
    end
    dictionary[data] = nil
    replicate_data[i] = nil
  end

  local result =
  {
    dictionary = dictionary;
    replicate_data = replicate_data;
    processed = processed;
    subdictionary = subdictionary;
  }
  -- so we can always reach parent table from subtable,
  -- though this makes our dictionary data structure heavily recursive
  for k, v in ordered_pairs(subdictionary) do
    dbg("making parent for", k)
    subdictionary[k].parent = result
  end
  return result
end


local prepare_manifest = function(metamanifest)
  arguments(
      "table", metamanifest
    )
  local metamanifest_plain = make_plain_dictionary(metamanifest.dictionary)
  metamanifest.dictionary = metamanifest_plain.dictionary
  metamanifest.replicate_data = metamanifest_plain.replicate_data
  metamanifest.processed = metamanifest_plain.processed
  metamanifest.subdictionary = metamanifest_plain.subdictionary
  return metamanifest
end

--------------------------------------------------------------------------------

return
{
  unify_manifest_dictionary = unify_manifest_dictionary;
  find_top_level_blocks = find_top_level_blocks;
  cut_wrappers = cut_wrappers;
  remove_wrappers = remove_wrappers;
  find_wrapped_values = find_wrapped_values;
  find_replicate_data = find_replicate_data;
  find_dictionary_data = find_dictionary_data;
  get_wrapped_string = get_wrapped_string;
  get_template_paths = get_template_paths;
  prepare_manifest = prepare_manifest;
}
