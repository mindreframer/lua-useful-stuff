--------------------------------------------------------------------------------
-- create_application_config_schema.lua: contains application config schema
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

local QIWI_PAYSYSTEM_ID,
      OD_PAYSYSTEM_ID,
      YM_PAYSYSTEM_ID
      = import 'pk-billing-lib/lib/lib/const.lua'
      {
        'QIWI_PAYSYSTEM_ID',
        'OD_PAYSYSTEM_ID',
        'YM_PAYSYSTEM_ID'
      }

--------------------------------------------------------------------------------

local create_application_config_schema
do
  local schema_chunk = function()
    cfg:root
    {
      cfg:string "title";
      cfg:string "id";
      cfg:node "api"
      {
        cfg:node "urls"
        {
          cfg:url "check_account";
          cfg:url "payment";
          cfg:url "correction";

          cfg:url "application";
          cfg:url "frontend";
        };
        cfg:boolean "use_url_query";
        cfg:string "format";
      };
      cfg:node "config"
      {
        cfg:optional_node "paysystems"
        {
          -- QIWI config
          cfg:optional_node (QIWI_PAYSYSTEM_ID)
          {
            cfg:string "from";
          };

          -- OD config
          cfg:optional_node (OD_PAYSYSTEM_ID)
          {
            cfg:string "project";
            cfg:string "source";
          };

          -- YandexMoney config
          cfg:optional_node (YM_PAYSYSTEM_ID)
          {
            cfg:string "shopId";
            cfg:string "scid";
          };
        };

        cfg:optional_string "qiwi_provider_passwd";
        cfg:optional_string "qiwi_provider_id";
        cfg:optional_string "ya_shop_password";
        cfg:optional_string "od_shop_passwd";

        cfg:optional_string "transaction_ttl";
        cfg:optional_string "qiwi_use_create_agt";
        cfg:optional_string "qiwi_use_alarm_sms";
        cfg:optional_string "qiwi_use_accept_call";

        cfg:optional_string "wm_secret_key";
        cfg:optional_string "wm_mode";
        cfg:optional_node "wm_wallets"
        {
          cfg:optional_string "wmz";
          cfg:optional_string "wmr";
          cfg:optional_string "wmu";
          cfg:optional_string "wme";
        };
        -- TODO: add more here

        cfg:optional_string "allowed_amounts_type";

        -- TODO: it must be a special node type
        -- https://redmine.iphonestudio.ru/issues/1791
        cfg:optional_freeform_table "amounts";
        cfg:optional_freeform_table "amounts_set";
        cfg:optional_freeform_table "amounts_to_pay";
        cfg:optional_freeform_table "rates";

        cfg:optional_freeform_table "currency_templates";

        cfg:optional_string "ssl_certificate_path";
        cfg:optional_string "ssl_certificate_password";
      };
    }
  end

  create_application_config_schema = function()
    return load_config_data_schema(
        schema_chunk
      )
  end
end

--------------------------------------------------------------------------------

return
{
  create_application_config_schema = create_application_config_schema;
}
