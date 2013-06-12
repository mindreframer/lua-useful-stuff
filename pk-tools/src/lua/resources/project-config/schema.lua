--------------------------------------------------------------------------------
-- schema.lua: project-config configuration file format
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
--      common_tool_config_schema_chunk();
-- TODO: remove common part, make it to include externally
--------------------------------------------------------------------------------
-- Temporarily added common part
  cfg:node "common"
  {
    cfg:existing_path "PROJECT_PATH";

    cfg:node "internal_config"
    {
      cfg:node "production"
      {
        cfg:host "host";
        cfg:port "port";
      };

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
      cfg:existing_path "tables_filename";
      cfg:existing_path "tables_test_data_filename";
    };

    cfg:node "resources"
    {
      cfg:existing_path "dir";
      cfg:path "path_prefix";
    };

    cfg:node "exports"
    {
      cfg:existing_path "exports_dir";
      cfg:existing_path "profiles_dir";

      cfg:non_empty_ilist "sources"
      {
        cfg:path "sources_dir";
        cfg:path "profile_filename";
        cfg:path "out_filename";
      };
    };

    cfg:node "www"
    {
      cfg:node "application"
      {
        cfg:url "url";
        cfg:path "session_checker_file_name";
        cfg:existing_path "api_schema_dir";
        cfg:boolean "have_unity_client";

        -- TODO: Refactor this section
        cfg:node "generated"
        {
          cfg:path   "file_root";
          cfg:path   "api_version_filename";
          cfg:path   "handlers_index_filename";
          cfg:path   "data_formats_filename";
          cfg:path   "handlers_dir_name";
          cfg:string "base_url_prefix";
          cfg:path   "unity_api_filename";
          cfg:path   "test_dir_name";
          cfg:existing_path "doc_latex_template_filename";
          cfg:path   "doc_md_filename";
          cfg:path   "doc_pdf_filename";
        };
      };
    };
  };
--------------------------------------------------------------------------------

      cfg:node "resources"
      {
        cfg:variant "action"
        {
          variants =
          {
            ["help"] =
            {
              -- No parameters
            };

            ["list"] =
            {
              -- No parameters
            };

            ["update"] =
            {
              -- No parameters
            };

            ["purge"] =
            {
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
