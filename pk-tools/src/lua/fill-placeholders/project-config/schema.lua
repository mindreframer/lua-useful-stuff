--------------------------------------------------------------------------------
-- schema.lua: fill-placeholders configuration file format
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

--------------------------------------------------------------------------------

      cfg:node "fill_placeholders"
      {
        cfg:existing_path "template_path";
        cfg:path "data_path";
        cfg:path "output_path";

        -- Ruby-like capture pattern #{} is picked as a default,
        -- since this is a command-line tool, intended to generate code.
        -- So we have to leave traditional ${} to the generated code itself.
        cfg:string "template_capture" { default = "#{(.-)}" };
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
