--------------------------------------------------------------------------------
-- config/schema-schema_tool.lua: schema tool configuration format schema
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

--------------------------------------------------------------------------------

local create_config_schema
do
  local schema_chunk = function()
  cfg:root
  {
    cfg:node "deploy_rocks"
    {
      cfg:variant "action"
      {
        variants =
        {
          ["help"] = { };
          ["check_config"] = { };
          ["dump_config"] = { };

          ["deploy_from_code"] = {
            cfg:string "cluster_name";
            cfg:existing_path "manifest_path";
            cfg:boolean "debug" { default = false };
            cfg:boolean "dry_run" { default = false };
            cfg:boolean "local_only" { default = false };
          };

          ["deploy_from_versions_file"] = {
            cfg:string "cluster_name";
            cfg:existing_path "manifest_path";
            cfg:boolean "debug" { default = false };
            cfg:boolean "dry_run" { default = false };
            cfg:boolean "local" { default = false };
            cfg:existing_path "version_filename";
          };

          ["partial_deploy_from_versions_file"] = {
            cfg:string "cluster_name";
            cfg:existing_path "manifest_path";
            cfg:boolean "debug" { default = false };
            cfg:boolean "dry_run" { default = false };
            cfg:boolean "local" { default = false };
            cfg:existing_path "version_filename";
            cfg:string "machine_name";
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

--------------------------------------------------------------------------------

return
{
  create_config_schema = create_config_schema;
}
