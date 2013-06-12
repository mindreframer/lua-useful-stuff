--------------------------------------------------------------------------------
-- schema.lua: db-changes configuration file format
-- This file is a part of pk-tools library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------

local load_tools_cli_data_schema
      = import 'pk-core/tools_cli_config.lua'
      {
        'load_tools_cli_data_schema'
      }
--[[
local common_tool_config_schema_chunk
      = import 'pk-tools.project-config.schema-common'
      {
        'common_tool_config_schema_chunk'
      }
]]
local create_config_schema

do
  local schema_chunk = function()
    cfg:root
    {
      cfg:node "common"
      {
        cfg:existing_path "PROJECT_PATH";

        cfg:node "internal_config"
        {
          cfg:node "deploy"
          {
            cfg:host "host";
            cfg:port "port";
          };
        };

        cfg:node "db"
        {
          cfg:existing_path "changes_dir";
        };
      };


      cfg:node "db_changes"
      {
        cfg:variant "action"
        {
          variants =
          {
            ["help"] =
            {
              -- No parameters
            };

            ["initialize_db"] =
            {
              cfg:non_empty_string "db_name";
              cfg:boolean "force" { default = false };
            };

            ["list_changes"] =
            {
              -- No parameters
            };

            ["upload_changes"] =
            {
              -- No parameters
            };

            ["revert_changes"] =
            {
              cfg:non_empty_string "stop_at_uuid";
            };
          };
        };
      };
    };
  end

  create_config_schema = function()
    return load_tools_cli_data_schema(
        schema_chunk
      )
  end
end

return
{
  create_config_schema = create_config_schema;
}
