--------------------------------------------------------------------------------
-- schema.lua: dbgen configuration file format
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
          cfg:existing_path "schema_filename";

          cfg:existing_path "changes_dir";

          cfg:path "tables_filename";
          cfg:path "tables_test_data_filename";

          cfg:path "generated_dot_filename";
          cfg:path "generated_pdf_filename";
        };
      };

      cfg:node "dbgen"
      {
        cfg:variant "action"
        {
          variants =
          {
            ["help"] =
            {
              -- No parameters
            };

            ["check"] =
            {
              -- No parameters
            };

            ["dottify"] =
            {
              -- No parameters
            };

            ["update_changes"] =
            {
              cfg:boolean "force" { default = false };
            };

            ["update_tables"] =
            {
              cfg:boolean "force" { default = false };
            };

            ["update_tables_test_data"] =
            {
              cfg:boolean "force" { default = false };
            };

            ["update_db"] =
            {
              cfg:boolean "force" { default = false };
            };

            ["update_data_changeset"] =
            {
              cfg:boolean "force" { default = false };
              cfg:non_empty_string "table_name";
              cfg:boolean "ignore_in_tests" { default = true };
            };
          };
        };
      };

    }
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
