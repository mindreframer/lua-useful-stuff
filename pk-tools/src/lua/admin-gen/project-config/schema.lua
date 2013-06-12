--------------------------------------------------------------------------------
-- schema.lua: admin-gen configuration file format
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

local create_config_schema

do
  local schema_chunk = function()
    cfg:root
    {
      cfg:node "common"
      {
        cfg:existing_path "PROJECT_PATH";
      };

      cfg:node "admin_gen"
      {
        intermediate =
        {
          cfg:path "api_schema_dir";
          cfg:path "js_dir";
        };

        cfg:existing_path "schema_filename";
        cfg:existing_path "template_js_dir";
        cfg:existing_path "template_api_dir";
        cfg:existing_path "db_schema_filename";

        cfg:variant "action"
        {
          variants =
          {
            ["help"] =
            {
              -- No parameters
            };

            ["generate_admin_api_schema"] =
            {
              -- No parameters
            };

            ["generate_js"] =
            {
              cfg:boolean "must_generate_navigator" { default = true };

              -- No parameters
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
