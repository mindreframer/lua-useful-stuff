--------------------------------------------------------------------------------
-- fill_placeholders_in_files.lua: fill placeholders in file(-s)
-- This file is a part of pk-core library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------

-- Create module loggers
local log, dbg, spam, log_error
      = import 'pk-core/log.lua' { 'make_loggers' } (
          "fill-placeholders", "FIL"
        )

--------------------------------------------------------------------------------

local table_sort = table.sort

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

local split_by_char,
      fill_placeholders_ex
      = import 'lua-nucleo/string.lua'
      {
        'split_by_char',
        'fill_placeholders_ex'
      }

local timap
      = import 'lua-nucleo/table-utils.lua'
      {
        'timap'
      }

local load_tools_cli_data_schema,
      load_tools_cli_config,
      print_tools_cli_config_usage,
      freeform_table_value
      = import 'pk-core/tools_cli_config.lua'
      {
        'load_tools_cli_data_schema',
        'load_tools_cli_config',
        'print_tools_cli_config_usage',
        'freeform_table_value'
      }

local load_all_files,
      write_file,
      read_file,
      create_path_to_file,
      find_all_files,
      is_directory
      = import 'lua-aplicado/filesystem.lua'
      {
        'load_all_files',
        'write_file',
        'read_file',
        'create_path_to_file',
        'find_all_files',
        'is_directory'
      }

local do_in_environment,
      make_config_environment
      = import 'lua-nucleo/sandbox.lua'
      {
        'do_in_environment',
        'make_config_environment'
      }

--------------------------------------------------------------------------------

-- TODO: To lua-nucleo/typeassert.lua
local assert_not_nil = function(v, m, ...)
  if v == nil then
    error(m, 2)
  end
  return v, m, ...
end

-- TODO: To lua-nucleo/table-utils.lua
local function tgetpath(t, k, nextk, ...)
  if k == nil then
    return nil
  end

  local v = t[k]
  if not is_table(v) or nextk == nil then
    return v
  end

  return tgetpath(v, nextk, ...)
end

--------------------------------------------------------------------------------

--[[
The `template_path` may be either a file or a directory.
If `template_path` is a directory, then `output_path` should also be a directory.

The `value_provider_code` is a string containing code somehow setting placeholder values.

If `output_path` is missing, it will be created.

template_capture is a Lua capture used in template files, default: `#{(.-)}'
]]
local fill_placeholders_in_files = function(
    template_path,
    value_provider_code,
    output_path,
    template_capture,
    filename_mask
  )
  arguments(
      "string", template_path,
      "string", value_provider_code,
      "string", output_path,
      "string", template_capture
    )
  optional_arguments(
      "string", filename_mask or ".*%.lua$"
    )

  filename_mask = filename_mask or ""

  local dictionary
  do
    local data = make_config_environment()
    assert(do_in_environment(loadstring(value_provider_code), data))

    dictionary = setmetatable(
        { },
        {
          __index = function(t, k)
            local v = rawget(data, k) -- Note rawget
            if v == nil and is_string(k) then -- Not found, maybe k is path?
              v = tgetpath(data, unpack(split_by_char(k, ".")))
            end

            local may_cache = true
            if is_function(v) then -- A handler
              v = v(dictionary)
              if v == nil then
                error("handler failed for `" .. tostring(k) .. "'")
              end
              may_cache = false -- Handler results are not cached
            end

            if v == nil then
              error("unknown placeholder `" .. tostring(k) .. "'")
            end

            if not (is_string(v) or is_number(v)) then
              error("wrong data type for placeholder `" .. tostring(k) .. "'")
            end

            v = tostring(v)

            if may_cache then
              t[k] = v
            end

            return v
          end;
        }
      )
  end

  local single_file_mode = true

  local template_filenames
  do
    if not assert_not_nil(is_directory(template_path)) then
      template_filenames = { template_path }
    else
      single_file_mode = false

      -- Ensure single trailing slash
      template_path = template_path:gsub("([^/])/*$", "%1/")
      template_filenames = assert(
          find_all_files(
              template_path,
              ".*" -- TODO: make this configurable
            )
        )
    end
    template_filenames = timap(
        function(s) return s:sub(#template_path + 1) end,
        template_filenames
      )
    table.sort(template_filenames)
  end

  if single_file_mode then
    assert(#template_filenames == 1)

    assert(create_path_to_file(output_path))
    assert(
        write_file(
            output_path,
            fill_placeholders_ex(
                template_capture,
                assert(
                    read_file(template_path .. template_filenames[1])
                  ),
                dictionary
              )
          )
      )
  else
    -- Ensure single trailing slash
    output_path = output_path:gsub("([^/])/*$", "%1/")

    for i = 1, #template_filenames do
      local filename = template_filenames[i]

      local in_filename = template_path .. filename
      local out_filename = output_path .. filename

      assert(create_path_to_file(out_filename))
      assert(
          write_file(
              out_filename,
              fill_placeholders_ex(
                  template_capture,
                  assert(
                      read_file(in_filename)
                    ),
                  dictionary
                )
            )
        )
    end
  end

  return true
end

--------------------------------------------------------------------------------

return
{
  fill_placeholders_in_files = fill_placeholders_in_files;
}
