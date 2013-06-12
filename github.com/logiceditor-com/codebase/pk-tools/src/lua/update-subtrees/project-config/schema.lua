--------------------------------------------------------------------------------
-- schema.lua
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
      cfg:node "update_config"
      {
        cfg:variant "action"
        {
          variants =
          {
            ["update"] = {
              cfg:existing_path "manifest_path";
              cfg:optional_string "subtree_name";
              cfg:optional_string "branch_name";
            };
          };
        };
      };
    }
  end

  create_config_schema = function()
    return load_tools_cli_data_schema(schema_chunk)
  end
end

--------------------------------------------------------------------------------

return
{
  create_config_schema = create_config_schema;
}
