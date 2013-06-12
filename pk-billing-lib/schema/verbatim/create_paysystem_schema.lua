--------------------------------------------------------------------------------
-- create_paysystem_schema.lua: contains paysystem schema
-- This file is a part of pk-billing-lib library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------

local assert, error = assert, error

--------------------------------------------------------------------------------

local log, dbg, spam, log_error
      = import 'pk-core/log.lua' { 'make_loggers' } (
          "internal_config/client", "ICC"
        )


local load_config_data_schema
      = import 'pk-billing-lib/lib/check_config.lua'
      {
        'load_config_data_schema'
      }

--------------------------------------------------------------------------------

local create_paysystem_schema
do
  local schema_chunk = function()
    cfg:root
    {
      cfg:string "id";
      cfg:string "frontend_id";
      cfg:string "title";
      cfg:string "create_form_script";

      cfg:node "config"
      {
        cfg:node "form"
        {
          cfg:string "action";
          cfg:string "method";
        };

        cfg:optional_freeform_table "subpaysystems";
      };

      cfg:optional_freeform_table "subpaysystems";
    }
  end

  create_paysystem_schema = function()
    return load_config_data_schema(
        schema_chunk
      )
  end
end

--------------------------------------------------------------------------------

return
{
  create_paysystem_schema = create_paysystem_schema;
}
