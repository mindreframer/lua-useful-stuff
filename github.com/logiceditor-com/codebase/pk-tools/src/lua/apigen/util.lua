--------------------------------------------------------------------------------
-- apigen/util.lua: apigen utility functions
-- This file is a part of pk-tools library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------

local log, dbg, spam, log_error
      = import 'pk-core/log.lua' { 'make_loggers' } (
          "apigen/util", "AUT"
        )

--------------------------------------------------------------------------------

local arguments,
      optional_arguments,
      method_arguments
      = import 'lua-nucleo/args.lua'
      {
        'arguments',
        'optional_arguments',
        'method_arguments',
        'eat_true'
      }

--------------------------------------------------------------------------------

-- TODO: WTF?! Shouldn't it be described in schema/client_api/types.lua?
local create_io_formats
do
  -- Context must contain following generators:
  --   string(min, max)
  --   identifier(min, max)
  --   url()
  --   db_id()
  --   number()
  --   integer()
  --   nonnegative_integer()
  --   text()
  --   uuid()
  --   ilist()
  --   node()
  --   list_node()
  --   int_enum(name)
  --   string_enum(name)
  --   optional()
  --   root()
  --
  create_io_formats = function(context)
    arguments("table", context)

    return
    {
      DB_ID = context.db_id();
      IP = context.string(1, 15);

      TEXT = context.text();
      TIMEOFDAY = context.integer(); -- TODO: Not integer, integer(11)!
      WEEKDAYS = context.integer(); -- TODO: Not integer, integer(11)!

      FILE = context.file();
      OPTIONAL_FILE = context.optional(context.file());

      OPTIONAL_DB_ID = context.optional(context.db_id());
      OPTIONAL_INTEGER = context.optional(context.integer());
      OPTIONAL_NUMBER = context.optional(context.number());
      OPTIONAL_IP = context.optional(context.string(1, 15));
      OPTIONAL_STRING256 = context.optional(context.string(1, 256));  -- Not recommended to use.
      OPTIONAL_STRING128 = context.optional(context.string(1, 128));  -- Not recommended to use.
      OPTIONAL_STRING64 = context.optional(context.string(1, 64));  -- Not recommended to use.
      OPTIONAL_IDENTIFIER16 = context.optional(context.identifier(1, 16));  -- Not recommended to use.
      OPTIONAL_TEXT = context.optional(context.text());
      OPTIONAL_TIMEOFDAY = context.optional(context.integer()); -- TODO: Not integer, integer(11)!
      OPTIONAL_WEEKDAYS = context.optional(context.integer()); -- TODO: Not integer, integer(11)!

      ACCOUNT_ID = context.db_id();
      ABSOLUTE_URL = context.url();
      OPTIONAL_ABSOLUTE_URL = context.optional(context.url());
      API_VERSION = context.identifier(1, 256);
      BLOB = context.text(); -- Not recommended to use.
      CLIENT_API_QUERY_PARAM = context.text();
      CLIENT_API_QUERY_URL = context.string_enum("CLIENT_API_QUERY_URLS");
      DELTA_TIME = context.integer(); -- TODO: Not integer, delta_time!
      DESCRIPTION = context.text();
      EXTRA_INFO = context.text();
      FULLNAME = context.string(1, 256);
      GARDEN_ARTICUL_ID = context.db_id();
      GARDEN_ID = context.db_id();
      GARDEN_SLOT_ID = context.db_id();
      GARDEN_SLOT_TYPE_ID = context.db_id(); -- TODO: Enum?
      INTEGER = context.integer();
      NUMBER = context.number();
      LIST = context.ilist();
      LIST_NODE = context.root(context.list_node());
      MONEY_GAME = context.nonnegative_integer();
      MONEY_REAL = context.nonnegative_integer();
      NICKNAME = context.string(1, 256);
      NODE = context.node();
      OPTIONAL_ACCOUNT_ID = context.optional(context.db_id());
      OPTIONAL_LIST = context.optional(context.ilist());
      OPTIONAL_NODE = context.optional(context.node());
      OPTIONAL_PLANT_GROUP_ID = context.optional(context.db_id()); -- TODO: delete?
      OPTIONAL_SESSION_ID = context.optional(context.uuid());
      PLANT_ARTICUL_ID = context.db_id();
      PLANT_CARE_ACTION_ID = context.db_id();
      PLANT_GROUP_ID = context.db_id(); -- TODO: delete?
      PLANT_GROWTH_STAGE_NUMBER = context.integer(); -- TODO: delete?
      PLANT_HEALTH = context.number();
      PLANT_ID = context.db_id();
      PRICE_GAME = context.nonnegative_integer();
      PRICE_REAL = context.nonnegative_integer();
      PUBLIC_PARTNER_API_TOKEN = context.text();
      RELATIVE_URL = context.url();
      RESOURCE_SIZE = context.nonnegative_integer();
      RESOURCE_ID = context.db_id();
      ROOT_LIST = context.root(context.ilist());
      ROOT_NODE = context.root(context.node());
      SESSION_ID = context.uuid();
      SESSION_TTL = context.integer();
      STAT_EVENT_ID = context.db_id();
      STRING256 = context.string(1, 256); -- Not recommended to use.
      STRING128 = context.string(1, 128); -- Not recommended to use.
      STRING64 = context.string(1, 64); -- Not recommended to use.
      IDENTIFIER16 = context.identifier(1, 16); -- Not recommended to use.
      TIMESTAMP = context.integer();
      TITLE = context.string(1, 256);

      MODIFIER_ARTICUL_ID = context.db_id();
      GARDEN_POINTS = context.integer();
      BOOLEAN = context.boolean();
      ACTION_ID = context.integer(); -- TODO: Not integer, enumeration!
      PLANT_LEVEL = context.nonnegative_integer(); -- TODO: value has limit
      GARDEN_LEVEL = context.nonnegative_integer(); -- TODO: value has limit
      MODIFIER_INCOME = context.integer(); -- TODO: float with limits
      MODIFIER_RESISTANCE = context.integer(); -- TODO: float with limits
      POSITIVE_INTEGER = context.nonnegative_integer();
      MODIFIER_GIFT_ID = context.db_id();
      REDEEM_CODE = context.integer(); -- TODO: probably fixed size
      EXCHANGE_RATE = context.nonnegative_integer();
      MONEY_PARTNER = context.nonnegative_integer();
      MODIFIER_PERMIRIAD_VALUE = context.integer();
      MODIFIER_LINEAR_VALUE = context.integer();
      GIFT_TYPE_ID = context.db_id();
      GIFT_ID = context.db_id();
      PARAMETER_NAME = context.string(1, 256);
      FOTOSTRANA_ACCOUNT_ID = context.identifier(1, 256);
      FOTOSTRANA_SESSION_ID = context.identifier(1, 256);
      IPHONE_ACCOUNT_ID = context.identifier(1, 256);
      IPHONE_SESSION_ID = context.identifier(1, 256);
      TEST_ACCOUNT_ID = context.identifier(1, 256);
      TEST_SESSION_ID = context.identifier(1, 256);
      MOIMIR_VID = context.identifier(1, 256);
      MOIMIR_AUTHENTIFICATION_KEY = context.identifier(1, 256);
      VKONTAKTE_USER_ID = context.identifier(1, 256);
      VKONTAKTE_AUTH_KEY = context.identifier(1, 256);

--------------------------------------------------------------------------------
-- TYPES FOR SPPIP
--------------------------------------------------------------------------------
      PAY_SYSTEM_ID = context.string(1, 64);
      PAY_SYSTEM_SUBID = context.optional(context.string(1, 64));
      APPLICATION_ID = context.string(1, 64);
      BILLING_ACCOUNT_ID = context.string(1, 256);
      PAYMENT_ID = context.string(1, 64);
      OPTIONAL_PAYMENT_ID = context.optional(context.string(1, 64));
      OPTIONAL_PAY_SYSTEM_ID = context.optional(context.string(1, 64));

--------------------------------------------------------------------------------
-- TYPES FOR MRX
--------------------------------------------------------------------------------
      COUNTRY_CODE = context.string(2, 2);
      OPTIONAL_COUNTRY_CODE = context.optional(context.string(2, 2));

--------------------------------------------------------------------------------
-- BEGIN POSTCARDS
--------------------------------------------------------------------------------
-- TODO MOVE ELSEWHERE
      POSTCARD_GROUP_ID = context.db_id();
      COMMON_TEXT_ID = context.db_id();
      POSTCARD_ID = context.db_id();
--------------------------------------------------------------------------------
-- END POSTCARDS
--------------------------------------------------------------------------------
    }
  end
end

--------------------------------------------------------------------------------

return
{
  create_io_formats = create_io_formats;
}
