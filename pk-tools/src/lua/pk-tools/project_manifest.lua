--------------------------------------------------------------------------------
-- project_manifest.lua: tools to work with project manifests
-- This file is a part of pk-tools library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------
-- TODO: Upgrade deploy-rocks to use this
--------------------------------------------------------------------------------

local log, dbg, spam, log_error
      = import 'pk-core/log.lua' { 'make_loggers' } (
          "deploy-rocks", "DRO"
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

local tset
      = import 'lua-nucleo/table-utils.lua'
      {
        'tset'
      }

local do_in_environment
      = import 'lua-nucleo/sandbox.lua'
      {
        'do_in_environment'
      }

local load_all_files_with_curly_placeholders
      = import 'lua-aplicado/filesystem.lua'
      {
        'load_all_files_with_curly_placeholders'
      }

local fill_curly_placeholders
      = import 'lua-nucleo/string.lua'
      {
        'fill_curly_placeholders'
      }

--------------------------------------------------------------------------------

-- TODO: Add validation, reuse tools_cli_config stuff.
local load_project_manifest
do
  -- We can not fill these right now:
  local ignored_placeholders = tset
  {
    "MACHINE_NODE_ID";
    "MACHINE_NAME";
  }

  local mt =
  {
    __index = function(t, k)
      if ignored_placeholders[k] then
        -- Put it back
        -- TODO: Hack.
        local v = "${" .. k .. "}"
        t[k] = v
        return v
      end

      error(
          "unknown placeholder: ${" .. (tostring(k) or "(not-a-string)") .. "}"
        )
    end;
  }

  load_project_manifest = function(
        manifest_path,
        project_path,
        cluster_name
      )
    arguments(
        "string", manifest_path,
        "string", project_path,
        "string", cluster_name
      )

    local chunks = assert(
        load_all_files_with_curly_placeholders(
            manifest_path,
            ".*%.lua$",
            setmetatable(
                {
                  PROJECT_PATH = project_path;
                  CLUSTER_NAME = cluster_name;
                },
                mt
              )
          )
      )

    local env =
    {
      import = import; -- This is a trusted sandbox
      assert = assert;
    }

    for i = 1, #chunks do
      assert(do_in_environment(chunks[i], env))
    end

    -- Hack. Use metatable instead.
    if env.import == import then
      env.import = nil
    end

    if env.assert == assert then
      env.assert = nil
    end

    return env
  end
end

--------------------------------------------------------------------------------

return
{
  load_project_manifest = load_project_manifest;
}
