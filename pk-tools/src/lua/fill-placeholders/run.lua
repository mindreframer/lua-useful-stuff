--------------------------------------------------------------------------------
-- run.lua: fill-placeholders runner
-- This file is a part of pk-tools library
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

local tgetpath
      = import 'lua-nucleo/table-utils.lua'
      {
        'tgetpath'
      }

local assert_not_nil
      = import 'lua-nucleo/typeassert.lua'
      {
        'assert_not_nil'
      }

--------------------------------------------------------------------------------

local create_config_schema
      = import 'fill-placeholders/project-config/schema.lua'
      {
        'create_config_schema'
      }

--------------------------------------------------------------------------------

local fill_placeholders_in_files = function(
    template_path,
    data_path,
    output_path,
    template_capture
  )
  arguments(
      "string", template_path,
      "string", data_path,
      "string", output_path,
      "string", template_capture
    )

  local dictionary
  do
    local data_chunks
    if not assert_not_nil(is_directory(data_path)) then
      data_chunks = { assert(loadfile(data_path)) }
    else
      -- Ensure single trailing slash
      data_path = data_path:gsub("([^/])/*$", "%1/")
      data_chunks = assert(
          load_all_files(
              data_chunks,
              ".*%.lua$" -- TODO: make this configurable
            )
        )
    end

    local data = make_config_environment()
    for i = 1, #data_chunks do
      assert(do_in_environment(data_chunks[i], data))
    end

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

local TOOL_NAME = "fill_placeholders"

--------------------------------------------------------------------------------

local EXTRA_HELP = [[

pk-fill-placeholders: placeholder filler tool

Usage:

    pk-fill-placeholders <template_path> <data_path> <output_path> [options]

The `template_path' and/or `data_path` may be either a file or a directory.

If `template_path` is a directory, then `output_path` should also be
a directory.

If `output_path` is missing, it will be created.

To pass data from command-line use `<()' bash trick:

    pk-fill-placeholders <(echo '#{key}') <(echo 'key=42') /dev/stdout

Options:

    --template-capture=<string>    Lua capture used in template files
                                   Default: `#{(.-)}'
]]

local CONFIG_SCHEMA = create_config_schema()

local CONFIG, ARGS

--------------------------------------------------------------------------------

local run = function(...)
  -- WARNING: Action-less tool. Take care when copy-pasting.

  CONFIG, ARGS = load_tools_cli_config(
      function(args) -- Parse actions
        local param = { }

        param.template_path = args[1]
        param.data_path = args[2]
        param.output_path = args[3]

        param.template_capture = args["--template-capture"]

        return
        {
          PROJECT_PATH = ""; -- TODO: Remove
          [TOOL_NAME] = param;
        }
      end,
      EXTRA_HELP,
      CONFIG_SCHEMA,
      nil, -- Specify primary config file with --base-config cli option
      nil, -- No secondary config file
      ...
    )

  if CONFIG == nil then
    local err = ARGS

    print_tools_cli_config_usage(EXTRA_HELP, CONFIG_SCHEMA)

    io.stderr:write("Error in tool configuration:\n", err, "\n\n")
    io.stderr:flush()

    os.exit(1)
  end

  ------------------------------------------------------------------------------

  fill_placeholders_in_files(
      CONFIG[TOOL_NAME].template_path,
      CONFIG[TOOL_NAME].data_path,
      CONFIG[TOOL_NAME].output_path,
      CONFIG[TOOL_NAME].template_capture
    )
end

return
{
  run = run;
}
