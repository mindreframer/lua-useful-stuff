--------------------------------------------------------------------------------
-- const.lua
-- This file is a part of pk-billing-lib library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------

api:export "lib/const"
{
  exports =
  {
    -- paysystems ids
    "QIWI_PAYSYSTEM_ID";
    "OD_PAYSYSTEM_ID";
    "OSMP_PAYSYSTEM_ID";
    "VK_PAYSYSTEM_ID";
    "YM_PAYSYSTEM_ID";
    "TEST_PAYSYSTEM_ID";
    "WM_PAYSYSTEM_ID";

    "MULTICURRENCY_PAYSYSTEMS";

    -- common project consts
    "PKB_COMMON_PREFIX";
    "PKB_COMMON_CACHE_PREFIX";
    "PKB_DEFAULT_TRANSACTION_TTL";
    "PKB_MIN_TRANSSACTION_AMOUNT";
    "PKB_ALLOWED_AMOUNTS_TYPES";
    "PKB_AMOUNTS_TYPE_FIXED";
    "PKB_AMOUNTS_TYPE_RANDOM";
    "PKB_DEFAULT_ALLOWED_AMOUNT_TYPE";
    "PKB_TIME_FILTER_OUT_FORMAT";
    "PKB_TIME_FILTER_IN_FORMAT";
    "PKB_PAYMENTS_CACHE_TTL";
    "PKB_RELOAD_PAYMENTS_CACHE_TTL";

    -- QIWI consts --
    "QIWI_API_URL";
    "QIWI_QUEUE_SIZE";
    "QIWI_MAX_REQUEST_COUNT";
    "QIWI_QUEUE_PART_SIZE";
    "QIWI_STATUSES";
    "QIWI_ERROR_CODES";

    "QIWI_DEFAULT_USE_CREATE_AGT";
    "QIWI_DEFAULT_USE_ALARM_SMS";
    "QIWI_DEFAULT_USE_ACCEPT_CALL";

    -- VK CONSTS --
    "VK_API_URL";
    "VK_QUEUE_SIZE";
    "VK_QUEUE_PART_SIZE";

    -- WEBMONEY CONSTS --
    "WM_DEFAULT_MODE";
    "WM_MODES";
    "WM_TRANSACTION_KEY_PREFIX";

    -- formats od requests to application
    "JSON_REQUEST_FORMAT";
    "XML_REQUEST_FORMAT";
    "LUABINS_REQUEST_FORMAT";
    "ALLOWED_REQEUST_FORMAT";

    -- kayako tocket constant
    "KAYAKO_TICKET_METHOD";
    "KAYAKO_TICKET_STATUS_ID";
    "KAYAKO_TICKET_PERIOD_ID";
    "KAYAKO_TICKET_AUTO_USER_ID";
    "KAYAKO_TICKET_TEXT_FORMAT";
  };

  handler = function()
    --paysystems ids
    local QIWI_PAYSYSTEM_ID = "fa857b3c-1a71-4f2b-aad3-5aba38dbb0de"    -- QIWI
    local OD_PAYSYSTEM_ID = "1ee56a6b-c2f8-4649-9a93-af1d6084433c"      -- OnlineDengi
    local OSMP_PAYSYSTEM_ID = "5f6a2b80-c5ab-11e0-8257-000c2980a4a0"    -- OSMP
    local VK_PAYSYSTEM_ID = "c4734b46-c813-11e0-a37e-c36dad27cbe5"      -- VKontakte
    local YM_PAYSYSTEM_ID = "54f0eaf0-87a7-11e0-be6f-000c29060bd8"      -- Yandex Money
    local TEST_PAYSYSTEM_ID = "f030af5f-e255-4fff-9f90-bfdc1caab48a" -- Test PS
    local WM_PAYSYSTEM_ID = "e80514b0-f10b-11e0-b645-00241d7f3992"      -- WebMoney

    -- TODO: must be generated
    -- https://redmine.iphonestudio.ru/issues/1487
    local MULTICURRENCY_PAYSYSTEMS =
    {
      [WM_PAYSYSTEM_ID] =
      {
        ["wmz"] = "Z%price%";
        ["wmu"] = "U%price%";
        ["wme"] = "E%price%";
        ["wmr"] = "R%price%";
      };
      [VK_PAYSYSTEM_ID] = "%price%";
    }

    local PKB_COMMON_PREFIX = "spp:"
    local PKB_COMMON_CACHE_PREFIX = PKB_COMMON_PREFIX .. "cache:"
    local PKB_DEFAULT_TRANSACTION_TTL = 1080
    local PKB_MIN_TRANSSACTION_AMOUNT = 0.01
    local PKB_TIME_FILTER_OUT_FORMAT = "%d/%m/%Y %H:%M %z"
    local PKB_TIME_FILTER_IN_FORMAT = "(%d+)/(%d+)/(%d+) (%d+):(%d+)"

    local PKB_PAYMENTS_CACHE_TTL = 600
    local PKB_RELOAD_PAYMENTS_CACHE_TTL = 600

    local PKB_AMOUNTS_TYPE_FIXED = "fixed"
    local PKB_AMOUNTS_TYPE_RANDOM = "random"
    local PKB_ALLOWED_AMOUNTS_TYPES =
    {
      [PKB_AMOUNTS_TYPE_RANDOM] = true;
      [PKB_AMOUNTS_TYPE_FIXED] = true;
    }
    local PKB_DEFAULT_ALLOWED_AMOUNT_TYPE = PKB_AMOUNTS_TYPE_RANDOM

    -- QIWI consts --
    local QIWI_API_URL = "http://ishop.qiwi.ru/xml"
    local QIWI_QUEUE_SIZE = 5000
    local QIWI_MAX_REQUEST_COUNT = 3

    local QIWI_DEFAULT_USE_CREATE_AGT = false
    local QIWI_DEFAULT_USE_ALARM_SMS = false    -- dont use "alarm sms"
    local QIWI_DEFAULT_USE_ACCEPT_CALL = false  -- dont use "accept call"

    -- max count of transactions in requst to qiwi
    -- qiwi set limit by 999 transactions in request
    local QIWI_QUEUE_PART_SIZE = 900

    -- statuses of transactions in Qiwi
    local QIWI_STATUSES =
    {
      TRANSACTION_NOT_HANDLED =
      {
        min = 0;
        max = 50;
      };
      TRANSACTION_IN_PROGRESS =
      {
        min = 51;
        max = 59;
      };
      TRANSACTION_HANDLED = 60;
      TRANSACTION_EXPIRED = 161;
      TRANSACTION_REJECTED =
      {
        min = 100;
      };
    }

    -- taken from QIWI: OnlineStoresProtocols_XML.pdf (https://docs.google.com/viewer?a=v&pid=explorer&chrome=true&srcid=0B55lDW7kaJMSNmFhZWQ3NDAtOTIwYy00OTMxLWI0OTEtZWUxMjE0MjU2ZWJh&hl=ru)
    local QIWI_ERROR_CODES =
    {
      [0] = "The operation completed successfully";
      [13] = "The server is busy, try again later";
      [150] = "Authorization error (invalid login/password)";
      [210] = "The bill was not found";
      [215] = "The bill with this txn-id already exists";
      [241] = "The payment amount is too small";
      [242] = "Exceeded maximum payment amount – 15 000 RUB"; -- maximum payment amount limited by QIWI
      [278] = "Maximum bill list retrieval interval exceeded";
      [298] = "Agent doesn't exist in the system";
      [300] = "Unknown error";
      [330] = "Encryption error";
      [339] = "IP address check failed";
      [370] = "Exceeded maximum number of concurrent requests";
      ["default"] = "Unknown error code";
    }

    -- VK CONSTS --
    local VK_API_URL = "http://api.vkontakte.ru/api.php"
    local VK_QUEUE_SIZE = 5000
    local VK_QUEUE_PART_SIZE = 900

    -- WEBMONEY CONSTS --
    local WM_MODES =
    {
      ["real"] = 0;
      ["test"] = 1;
    }
    local WM_DEFAULT_MODE = "test"
    local WM_TRANSACTION_KEY_PREFIX = "spp:webmoney:"

    -- formats od requests to application
    local JSON_REQUEST_FORMAT = "json"
    local XML_REQUEST_FORMAT = "xml"
    local LUABINS_REQUEST_FORMAT = "luabins"
    local ALLOWED_REQEUST_FORMAT = tset { JSON_REQUEST_FORMAT, XML_REQUEST_FORMAT, LUABINS_REQUEST_FORMAT }

    -- kayako const
    local KAYAKO_TICKET_METHOD = "/Tickets/Ticket"
    local KAYAKO_TICKET_STATUS_ID = "1"
    local KAYAKO_TICKET_PERIOD_ID = "1"
    local KAYAKO_TICKET_AUTO_USER_ID = "1"
    local KAYAKO_TICKET_TEXT_FORMAT = "Аккаунт в банке %s\r\nНазвание игры %s\r\n\r\n%s"
  end;
}
