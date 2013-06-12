--------------------------------------------------------------------------------
-- replicate_data.lua: project-create replicate functions
-- This file is a part of pk-project-tools library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------

local loadfile, loadstring = loadfile, loadstring

--------------------------------------------------------------------------------

local log, dbg, spam, log_error
      = import 'pk-core/log.lua' { 'make_loggers' } (
          "project-create/replicate-data", "RPD"
        )

--------------------------------------------------------------------------------

local lfs = require 'lfs'

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
      tisempty,
      empty_table
      = import 'lua-nucleo/table-utils.lua'
      {
        'tgetpath',
        'tclone',
        'twithdefaults',
        'tset',
        'tiflip',
        'tisempty',
        'empty_table'
      }

local ordered_pairs
      = import 'lua-nucleo/tdeepequals.lua'
      {
        'ordered_pairs'
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

local luarocks_show_rock_dir
      = import 'lua-aplicado/shell/luarocks.lua'
      {
        'luarocks_show_rock_dir'
      }

local copy_file_with_flag,
      copy_file,
      remove_file,
      remove_recursively
      = import 'lua-aplicado/shell/filesystem.lua'
      {
        'copy_file_with_flag',
        'copy_file',
        'remove_file',
        'remove_recursively'
      }

local shell_read,
      shell_exec
      = import 'lua-aplicado/shell.lua'
      {
        'shell_read',
        'shell_exec'
      }

local split_by_char,
      escape_lua_pattern
      = import 'lua-nucleo/string.lua'
      {
        'split_by_char',
        'escape_lua_pattern'
      }

local tpretty
      = import 'lua-nucleo/tpretty.lua'
      {
        'tpretty'
      }

local tstr
      = import 'lua-nucleo/tstr.lua'
      {
        'tstr'
      }

local find_top_level_blocks,
      find_replicate_data,
      find_dictionary_data,
      get_wrapped_string,
      cut_wrappers,
      remove_wrappers,
      find_wrapped_values
      = import 'pk-project-create/common_functions.lua'
      {
        'find_top_level_blocks',
        'find_replicate_data',
        'find_dictionary_data',
        'get_wrapped_string',
        'cut_wrappers',
        'remove_wrappers',
        'find_wrapped_values'
      }

--------------------------------------------------------------------------------

-- TODO: until manual log level will be available #3775
dbg = function() end
spam = function() end

--------------------------------------------------------------------------------

local remove_false_block = function(manifest, string_to_process, wrapper)
  arguments(
      "table", manifest,
      "string", string_to_process,
      "table", wrapper
    )
  local dictionary = manifest.dictionary
  for k, v in ordered_pairs(dictionary) do
    if v == false then
      --find block
      local string_to_find = get_wrapped_string(k, wrapper)
      local blocks = {}
      for w in string_to_process:gmatch(string_to_find) do
        blocks[#blocks + 1] = w
      end
      for j = 1, #blocks do
        --remove found block
        string_to_process = string_to_process:gsub(
            blocks[j]:gsub("[%p%%]", "%%%1"),
            "\n"
          )
      end
    end
  end
  return string_to_process
end

--------------------------------------------------------------------------------

-- TODO: move to lua-nucleo #3736
local check_trailspaces_newlines = function(file_content)
  return file_content:gsub("[ \t]*\n", "\n"):gsub("\n\n[\n]+", "\n"):gsub("\n\n$", "\n")
end

--------------------------------------------------------------------------------

local replace_pattern_in_string = function(
    string_to_process,
    key,
    value,
    data_wrapper
  )

  if is_string(value) then
    return string_to_process:gsub(
        escape_lua_pattern(data_wrapper.left .. key .. data_wrapper.right),
        (value:gsub("%%", "%%%1"))
      )
  elseif value == false then
    -- Remove all strings with pattern that == false
    return string_to_process:gsub(
        "\n[.]*"
     .. escape_lua_pattern(data_wrapper.left .. key .. data_wrapper.right)
     .. "[.]*\n",
        "\n"
      )
  else
    log_error(value, "is not string or false in manifest dictionary for", key)
    error("manifest dictionary has not string or false value")
  end
end

--------------------------------------------------------------------------------

local replace_value_in_string_using_parent = function(
    string_to_process,
    value,
    manifest,
    replaces_used,
    data_wrapper,
    modificators_used
  )
  modificators_used = modificators_used or { }
  replaces_used = replaces_used or { }
  arguments(
      "string", string_to_process,
      "string", value,
      "table", manifest,
      "table", replaces_used,
      "table", data_wrapper,
      "table", modificators_used
    )
  local value_to_use = find_dictionary_data(manifest, value, replaces_used)

  if modificators_used and value_to_use then
    for i = 1, #modificators_used do
      value_to_use = modificators_used[i](value_to_use)
    end
  end

  if value_to_use then
    return replace_pattern_in_string(
        string_to_process,
        modificators_used.value or value,
        value_to_use,
        data_wrapper
      )
   end
  return string_to_process
end

--------------------------------------------------------------------------------

local function parse_modificators(value, wrapper, modificators, modificators_used)
  modificators_used = modificators_used or { value = value }
  modificators = modificators or { }
  arguments(
      "string", value,
      "table", wrapper,
      "table", modificators,
      "table", modificators_used
    )

  dbg("modificators", modificators)
  dbg("parsing", value, modificators_used)
  local wrapper_left_start, wrapper_left_end = value:find(wrapper.left, nil, true)
  if wrapper_left_end then
    local val = value:sub(1, wrapper_left_start - 1)
    if modificators[val] then
      modificators_used[#modificators_used + 1] = modificators[val]
    else
      error("Wrong modificator found: " .. val)
    end
    parse_modificators(
        value:sub(wrapper_left_start + 1),
        wrapper,
        modificators,
        modificators_used
      )
  else
    local wrapper_right_start = value:find(wrapper.right, nil, true)
    if wrapper_right_start then
      modificators_used.param = value:sub(1, wrapper_right_start - 1)
    end
  end
  return modificators_used
end

--------------------------------------------------------------------------------

local replace_dictionary_in_string = function(
    manifest,
    string_to_process,
    data_wrapper,
    modificator_wrapper,
    modificators,
    replaces_used
  )
  replaces_used = replaces_used or { }
  arguments(
      "table", manifest,
      "string", string_to_process,
      "table", data_wrapper,
      "table", modificator_wrapper,
      "table", modificators,
      "table", replaces_used
    )

  local values = find_wrapped_values(string_to_process, data_wrapper)
  if not values then
    return string_to_process
  end
  dbg("found wrapped values:", values)
  for i = 1, #values do
    local value = values[i]
    local modificators_used = parse_modificators(value, modificator_wrapper, modificators)
    dbg("modificators_used.param", modificators_used.param)
    string_to_process = replace_value_in_string_using_parent(
        string_to_process,
        modificators_used.param or value,
        manifest,
        replaces_used,
        data_wrapper,
        modificators_used
      )
  end
  return string_to_process
end

--------------------------------------------------------------------------------

local function replicate_and_replace_in_file_recursively(
      manifest,
      file_content,
      replaces_used,
      wrapper,
      modificators,
      nested
    )
  replaces_used = replaces_used or { }
  modificators = modificators or { }
  nested = nested or 0
  arguments(
      "table", manifest,
      "string", file_content,
      "table", replaces_used,
      "table", wrapper,
      "table", modificators,
      "number", nested
    )

  local replicate_data = tclone(manifest.replicate_data)
  local dictionary = tclone(manifest.dictionary)
  local subdictionary = manifest.subdictionary

  dbg("[" .. nested .. "] ","[replicate_and_replace_in_file_recursively]")
  dbg("[" .. nested .. "] ","replaces_used:", tstr(replaces_used))

  -- replace patterns already fixed for this part of text (or file)
  for k, v in ordered_pairs(replaces_used) do
    dbg("[" .. nested .. "] ","replaces_used k, v:",  k, v)
    file_content = replace_dictionary_in_string(
        {
          dictionary =
          {
            [k] = find_dictionary_data(
                manifest.subdictionary[v] or manifest,
                v,
                replaces_used
              );
          };
        },
        file_content,
        wrapper.data,
        wrapper.modificator,
        modificators
      )
  end

  local top_level_blocks = find_top_level_blocks(file_content, wrapper.block, replaces_used)
  dbg("[" .. nested .. "] ","[top_level_blocks]", tpretty(top_level_blocks))

  for i = 1, #top_level_blocks do
    local block = top_level_blocks[i]
    local value = block.value
    local text = block.text

    local value_replicates = find_replicate_data(manifest, value, replaces_used)

    -- no replicates found, use dictionary value
    if value_replicates == nil then
      value_replicates = { value }
    end

    block.replicas = { }
    dbg("[" .. nested .. "] ","[value_replicates]", tstr(value_replicates), block.value)

    -- "false" value processed here
    if tisempty(value_replicates) then
      block.replicas[#block.replicas + 1] = ""
    end

    -- replicated values processed here
    for j = 1, #value_replicates do
      dbg("[" .. nested .. "] ","value_replicates[" .. j .. "]", value_replicates[j])
      spam("[" .. nested .. "] ","[replication] before", text)

      local current_block_replica =  replace_dictionary_in_string(
          {
            dictionary =
            {
              [value] = find_dictionary_data(
                  manifest,
                  value_replicates[j],
                  replaces_used
                );
            };
          },
          text,
          wrapper.data,
          wrapper.modificator,
          modificators
        )

      spam("[" .. nested .. "] ","[replication] after", current_block_replica)
      current_block_replica = replace_value_in_string_using_parent(
          current_block_replica,
          value_replicates[j],
          manifest,
          replaces_used,
          wrapper.data
        )

      local submanifest = manifest
      if subdictionary[value_replicates[j]] then
        submanifest = subdictionary[value_replicates[j]]
      end
      local replaces_used_sub = tclone(replaces_used)
      replaces_used_sub[value] = value_replicates[j]

      current_block_replica = replicate_and_replace_in_file_recursively(
          submanifest,
          current_block_replica,
          replaces_used_sub,
          wrapper,
          modificators,
          nested + 1
        )

      spam("[" .. nested .. "] ","[cut_wrappers] before", current_block_replica)
      current_block_replica = cut_wrappers(
          current_block_replica,
          wrapper.block,
          value
        )
      spam("[" .. nested .. "] ","[cut_wrappers] after", current_block_replica)

      block.replicas[#block.replicas + 1] = current_block_replica
    end -- for j = 1, #value_replicates do

    file_content = file_content:gsub(
        block.text:gsub("[%p%%]", "%%%1"),
        table.concat(block.replicas, "")
      )
  end -- for i = 1, #top_level_blocks do

  -- removing blocks with "false" dictionary patterns
  file_content = remove_false_block(
      manifest,
      file_content,
      wrapper.block
    )

  file_content = remove_wrappers(file_content, wrapper.block)

  spam("[" .. nested .. "] ","dictionary", tstr(dictionary))
  spam("[" .. nested .. "] ","file_content before replace (end)", file_content)
  file_content = replace_dictionary_in_string(
      manifest,
      file_content,
      wrapper.data,
      wrapper.modificator,
      modificators,
      replaces_used
    )
  spam("[" .. nested .. "] ","file_content after replace (end)", file_content)
  return file_content
end

--------------------------------------------------------------------------------

local function get_already_used_replaces(
    fs_structure,
    replaces
  )
  replaces = replaces or { }
  arguments(
      "table", fs_structure,
      "table", replaces
    )

  if fs_structure.replaces_used then
    for k, v in ordered_pairs(fs_structure.replaces_used) do
      if replaces[k] == nil then
        replaces[k] = v
      else
        dbg("Double replacement found:", fs_structure.replaces_used, "replaces", replaces)
      end
    end
  end

  if fs_structure.parent then
    return get_already_used_replaces(fs_structure.parent, replaces)
  else
    return replaces
  end
end

--------------------------------------------------------------------------------

local replicate_and_replace_in_file = function(
    filename,
    fileinfo,
    wrapper,
    modificators
  )
  modificators = modificators or empty_table
  arguments(
      "string", filename,
      "table", fileinfo,
      "table", wrapper,
      "table", modificators
    )
  local file_content = read_file(fileinfo.original_file.path)

  if not (does_file_exist(fileinfo.path) and fileinfo.do_not_replace) then
    file_content = replicate_and_replace_in_file_recursively(
        fileinfo.manifest_local,
        file_content,
        get_already_used_replaces(fileinfo, fileinfo.replaces_used),
        wrapper,
        modificators
      )
    create_path_to_file(fileinfo.path)
    write_file(fileinfo.path, check_trailspaces_newlines(file_content))
  else
    dbg(fileinfo.path, "marked as ignored")
  end
end

--------------------------------------------------------------------------------

local create_replicated_entries = function(
    filename,
    fileinfo,
    manifest,
    fs_structure,
    wrapper
  )
  arguments(
      "string", filename,
      "table", fileinfo,
      "table", manifest,
      "table", fs_structure,
      "table", wrapper
    )

  local values = find_wrapped_values(filename, wrapper) or empty_table

  local replaces = { }
  local used_replaces = get_already_used_replaces(fs_structure)

  local local_used_replaces = { }
  for i = 1, #values do
    local value = values[i]
    dbg("[c_r_e] value:",  value)
    if used_replaces[value] then
       dbg("[c_r_e] used_replaces:",  value, used_replaces[value])
      local_used_replaces[value] = used_replaces[value]
    else
      replaces[value] = find_replicate_data(manifest, value)
      dbg("[c_r_e] replaces[value]:",  value, replaces[value])
      -- processing false in dictionary
      if is_table(replaces[value]) and tisempty(replaces[value]) then
        return { }
      end
    end
    if not replaces[value] and not used_replaces[value] then
      filename = filename:gsub(
          escape_lua_pattern(wrapper.left .. value .. wrapper.right),
          assert(find_dictionary_data(manifest, value))
        );
    end
  end
  dbg("[c_r_e] filename:", filename)

  -- replace patterns already fixed for this part of text (or file)
  local replicas = { }
  for k, v in ordered_pairs(local_used_replaces) do
    dbg("[c_r_e] replaces_used k, v:",  k, v)
    if tisempty(replicas) then
      replicas[#replicas + 1] =
      {
        filename = filename:gsub(
            escape_lua_pattern(wrapper.left .. k .. wrapper.right),
            find_dictionary_data(manifest, v)
          );
        replaces_used = { }; --[k] = v };
        original_file = fileinfo;
        manifest = manifest;
      }
    else
      for j = 1, #replicas do
        replicas[j].filename = replicas[j].filename:gsub(
            escape_lua_pattern(wrapper.left .. k .. wrapper.right),
            find_dictionary_data(manifest, v)
          );
      end
    end
  end
  dbg("[c_r_e] filename (2):", filename)

  for i = 1, #values do
    local value = values[i]
    if replaces[value] then
      if tisempty(replicas) then
        for j = 1, #replaces[value] do
          replicas[#replicas + 1] =
          {
            filename = filename:gsub(
                escape_lua_pattern(wrapper.left .. value .. wrapper.right),
                find_dictionary_data(
                    manifest.subdictionary[replaces[value][j]] or manifest,
                    replaces[value][j]
                  )
              );
            replaces_used = { [value] = replaces[value][j] };
            original_file = fileinfo;
            manifest = manifest.subdictionary[replaces[value][j]] or manifest;
          }
        end
      else
        local new_replicas = { }
        for j = 1, #replaces[value] do
          for k = 1, #replicas do
            local replaces_used = tclone(replicas[k].replaces_used)
            replaces_used[value] = replaces[value][j]
            local val = find_dictionary_data(manifest, replaces[value][j])
            new_replicas[#new_replicas + 1] =
            {
              filename = replicas[k].filename:gsub(
                  escape_lua_pattern(wrapper.left .. value .. wrapper.right),
                  find_dictionary_data(
                      replicas[k].manifest or
                      (manifest.subdictionary[replaces[value][j]] or manifest),
                      replaces[value][j]
                    )
                );
              replaces_used = replaces_used;
              original_file = fileinfo;
              manifest =
                (replicas[k].manifest or
                (manifest.subdictionary[replaces[value][j]] or manifest));
            }
          end
        end
        replicas = new_replicas
      end
    end
  end
  dbg("[c_r_e] filename end:", filename)

  if
    tisempty(values) or
    (values and tisempty(replicas))
  then
    return
    {
      {
        filename = filename;
        replaces_used = { };
        original_file = fileinfo;
        manifest = manifest;
      }
    }
  end

  if
    values and tisempty(replaces) and tisempty(local_used_replaces)
  then
    return { }
  end

  return replicas
end

--------------------------------------------------------------------------------

local function create_project_fs_structure(
    curr_fs_struct,
    curr_manifest,
    curr_fs_struct_replicated,
    curr_path,
    wrapper
  )
  curr_fs_struct_replicated = curr_fs_struct_replicated or
  {
    path = "";
    type = "directory";
    children = { };
    do_not_replace = false;
  }
  curr_path = curr_path or curr_manifest.project_path
  wrapper = wrapper or curr_manifest.wrapper.fs
  arguments(
      "table", curr_fs_struct,
      "table", curr_manifest,
      "table", curr_fs_struct_replicated,
      "table", wrapper
    )

  for k, v in ordered_pairs(curr_fs_struct.children) do
    dbg("----------------------------------------------")
    dbg("starting to process file: ", k)
    local new_entries = create_replicated_entries(
        k,
        v,
        curr_manifest,
        curr_fs_struct_replicated,
        wrapper
      )

    for i = 1, #new_entries do
      local entry = new_entries[i]
      dbg("going for entry", entry.filename)
      local path = curr_path .. "/" .. entry.filename
      curr_fs_struct_replicated.children[entry.filename] =
      {
        path = path;
        parent = curr_fs_struct_replicated;
        type = v.type;
        children = { };
        do_not_replace = v.do_not_replace;
        replaces_used = entry.replaces_used;
        original_file = entry.original_file;
        manifest_local = entry.manifest;
      }
      if v.type == "directory" then
        create_project_fs_structure(
            v,
            entry.manifest,
            curr_fs_struct_replicated.children[entry.filename],
            path,
            wrapper
          )
      end
    end
  end

  return curr_fs_struct_replicated
end

--------------------------------------------------------------------------------

local function make_project_using_fs_structure(fs_struct, metamanifest)
  arguments(
      "table", fs_struct,
      "table", metamanifest
    )
  local wrapper = metamanifest.wrapper or { }
  local modificators = metamanifest.modificators or { }

  for k, v in ordered_pairs(fs_struct.children) do
    if v.type == "directory" then
      make_project_using_fs_structure(v, metamanifest)
    else
      replicate_and_replace_in_file(k, v, wrapper, modificators)
    end
  end
end

--------------------------------------------------------------------------------

return
{
  create_project_fs_structure = create_project_fs_structure;
  make_project_using_fs_structure = make_project_using_fs_structure;
  replicate_and_replace_in_file_recursively = replicate_and_replace_in_file_recursively;
}
