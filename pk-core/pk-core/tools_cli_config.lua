--------------------------------------------------------------------------------
-- tools_cli_config.lua: tools CLI/configuration handler
-- This file is a part of pk-core library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------
-- Sandbox warning: alias all globals!
--------------------------------------------------------------------------------

local log, dbg, spam, log_error
      = import 'pk-core/log.lua' { 'make_loggers' } (
         "tools_cli_config", "TCC"
       )

--------------------------------------------------------------------------------

local is_function
      = import 'lua-nucleo/type.lua'
      {
        'is_function'
      }

local arguments,
      optional_arguments
      = import 'lua-nucleo/args.lua'
      {
        'arguments',
        'optional_arguments'
      }

local tstr
      = import 'lua-nucleo/tstr.lua'
      {
        'tstr'
      }

local unique_object
      = import 'lua-nucleo/misc.lua'
      {
        'unique_object'
      }

local get_tools_cli_data_walkers
      = import 'pk-core/config_dsl.lua'
      {
        'get_data_walkers'
      }

local load_data_schema
      = import 'pk-core/walk_data_with_schema.lua'
      {
        'load_data_schema'
      }

local do_in_environment,
      dostring_in_environment,
      make_config_environment
      = import 'lua-nucleo/sandbox.lua'
      {
        'do_in_environment',
        'dostring_in_environment',
        'make_config_environment'
      }

local load_all_files,
      find_all_files
      = import 'lua-aplicado/filesystem.lua'
      {
        'load_all_files',
        'find_all_files'
      }

local empty_table,
      tclone,
      twithdefaults,
      treadonly
      = import 'lua-nucleo/table-utils.lua'
      {
        'empty_table',
        'tclone',
        'twithdefaults',
        'treadonly'
      }

local make_config_environment
      = import 'lua-nucleo/sandbox.lua'
      {
        'make_config_environment'
      }

local dump_nodes
      = import 'pk-core/dump_nodes.lua'
      {
        'dump_nodes'
      }

--------------------------------------------------------------------------------

local load_tools_cli_data_schema
do
  local extra_env =
  {
    import = import; -- Trusted sandbox
  }

  load_tools_cli_data_schema = function(schema_chunk)
    arguments("function", schema_chunk)
    return load_data_schema(schema_chunk, extra_env, { "cfg" })
  end
end

--------------------------------------------------------------------------------

local load_tools_cli_data
do
  load_tools_cli_data = function(schema, data, env)
    if is_function(schema) then
      schema = load_tools_cli_data_schema(schema)
    end

    arguments(
        "table", schema,
        "table", data
      )

    local checker = get_tools_cli_data_walkers()
      :walk_data_with_schema(
          schema,
          data,
          data -- use data as environment for string_to_node
        )
      :get_checker()

    if not checker:good() then
      return checker:result()
    end

    return data
  end
end

--------------------------------------------------------------------------------

local parse_tools_cli_arguments = function(canonicalization_map, ...)
  arguments("table", canonicalization_map)

  local n = select("#", ...)

  local args = { }

  local i = 1
  while i <= n do
    local arg = select(i, ...)
    if arg:match("^%-%-[^%-=].-=.*$") then
      -- TODO: Optimize. Do not do double matching
      local name, value = arg:match("^(%-%-[^%-=].-)=(.*)$")
      assert(name)
      assert(value)
      args[canonicalization_map[name] or name] = value
    elseif arg:match("^%-[^%-].*$") then
      local name = arg

      i = i + 1
      local value = select(i, ...)

      args[canonicalization_map[name] or name] = value
    elseif arg:match("^%-%-[^%-].*$") then
      -- TODO: Optimize. Do not do double matching
      local name, value = arg, true
      assert(name)
      assert(value)
      args[canonicalization_map[name] or name] = value
    else
      local name = canonicalization_map[arg] or arg
      args[#args + 1] = name
      args[name] = true
    end
    i = i + 1
  end

  return args
end

--------------------------------------------------------------------------------

local print_tools_cli_config_usage = function(extra_help, schema)
  arguments(
      "string", extra_help,
      "table", schema
    )

  io.stdout:write(extra_help)

  io.stdout:write([[

Options:

    --help                     Print this text
    --dump-format              Print config file format
    --root=<path>              Absolute path to project
    --param=<lua-table>        Add data from lua-table to config
    --config=<filename>        Override config filename
    --no-config                Do not load project config file
    --base-config=<filename>   Override base config filename
    --no-base-config           Do not load base project config file

]])

  io.stdout:flush()

end

local print_format = function(schema)
  arguments(
      "table", schema
    )

  io.stdout:write([[

Config format:

]])

  -- TODO: Output should be more Lua-like!
  dump_nodes(
      schema, -- dump schema
      "-",    -- to stdout
      "id",   -- tag field
      "name", -- name field
      true,   -- with indent
      true    -- with names
    )

  io.stdout:flush()

end

--------------------------------------------------------------------------------

local raw_config_table_key = unique_object()

local raw_config_table_callback = function(t)
  return t
end

-- TODO: Hack. Protect only data defined in schema!
local freeform_table_value = function(t)
  return tclone(assert(t[raw_config_table_key])())
end

-- TODO: Too rigid. Must be more flexible.
local load_tools_cli_config
do
  local callbacks = { [raw_config_table_key] = raw_config_table_callback }

  load_tools_cli_config = function(
      arg_to_param_mapper,
      extra_help,
      schema,
      base_config_filename,
      project_config_filename,
      ... -- Pass cli arguments here
    )
    arguments(
        "table", schema
      )

    optional_arguments(
        "string", base_config_filename,
        "string", project_config_filename
      )

    local args = parse_tools_cli_arguments(
        empty_table,
        ...
      )

    local help_printed = false
    if args["--help"] then
      print_tools_cli_config_usage(extra_help, schema)
      help_printed = true
    end

    if args["--dump-format"] then
      print_format(schema)
      help_printed = true
    end

    if help_printed then
      return os.exit(1) -- TODO: This is caller's business!
    end

    -- Note tclone()
    local CONFIG = arg_to_param_mapper(tclone(args))

    -- TODO: WTF?! Rewrite this whole thing!
    local CONFIG_OVERRIDE = tclone(CONFIG)

    -- Hack. Implicitly forcing config schema to have PROJECT_PATH key
    -- Better to do this explicitly somehow?
    local PROJECT_PATH = assert(
        CONFIG.PROJECT_PATH,
        "missing PROJECT_PATH"
      )

    -- TODO: Uberhack, remove!
    CONFIG.import = import
    CONFIG.rawget = rawget

    CONFIG = make_config_environment(CONFIG)

    local project_config_filename = args["--config"] or project_config_filename
    local base_config_filename = args["--base-config"] or base_config_filename

    if args["--param"] then
      assert(dostring_in_environment(args["--param"], CONFIG, "@--param"))
    end

    -- TODO: Hack? Only base and project configs are allowed import()
    -- TODO: Let user to specify environment explicitly instead.
    if not args["--no-base-config"] and base_config_filename then
      --[[
      io.stdout:write(
          "--> loading base config file ", base_config_filename, "\n"
        )
      io.stdout:flush()
      --]]

      local attr = assert(lfs.attributes(base_config_filename))
      if attr.mode == "directory" then
        local base_config_files = find_all_files(base_config_filename, ".")
        local base_config_chunks = load_all_files(base_config_filename, ".")
        for i = 1, #base_config_chunks do
          assert(do_in_environment(base_config_chunks[i], CONFIG))
        end
      else
        local base_config_chunk = assert(loadfile(base_config_filename))
        assert(do_in_environment(base_config_chunk, CONFIG))
      end
    end

    if not args["--no-config"] and project_config_filename then
      --[[
      io.stdout:write(
          "--> loading project config file ", project_config_filename, "\n"
        )
      io.stdout:flush()
      --]]
      local attr = assert(lfs.attributes(project_config_filename))
      if attr.mode == "directory" then
        local project_config_files = find_all_files(
            project_config_filename,
            "."
          )
        local project_config_chunks = load_all_files(
            project_config_filename,
            "."
          )
        for i = 1, #project_config_chunks do
          assert(do_in_environment(project_config_chunks[i], CONFIG))
        end
      else
        local project_config_chunk = assert(loadfile(project_config_filename))
        assert(do_in_environment(project_config_chunk, CONFIG))
      end
    end

    if CONFIG.import == import then
      CONFIG.import = nil -- TODO: Hack. Use metatables instead
    end

    if CONFIG.rawget == rawget then
      CONFIG.rawget = nil -- TODO: Hack. Use metatables instead
    end

    -- Hack. Doing tclone() to remove __metatabled metatable
    CONFIG = twithdefaults(CONFIG_OVERRIDE, tclone(CONFIG))

    --[[
    io.stdout:write("--> validating cumulative config\n")
    io.stdout:flush()
    --]]

    local err

    CONFIG, err = load_tools_cli_data(schema, CONFIG)
    if CONFIG == nil then
      return nil, err
    end

    return treadonly(CONFIG, callbacks, tstr), args
  end
end

--------------------------------------------------------------------------------

return
{
  load_tools_cli_data_schema = load_tools_cli_data_schema;
  load_tools_cli_config = load_tools_cli_config;
  print_tools_cli_config_usage = print_tools_cli_config_usage;
  freeform_table_value = freeform_table_value;
  -- Export more as needed.
}
