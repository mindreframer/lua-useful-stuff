--------------------------------------------------------------------------------
-- common.lua
-- This file is a part of pk-billing-lib library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------

api:export "lib/common"
{
  exports =
  {
    "PKB_APPLICATION_CONFIG_SECTION";
    "PKB_ALLOWED_API_FORMATS";

    "PKB_TIME_INTERVAL";
    "PKB_REQUEST_FIELDS";
    "PKB_REQUEST_OPTIONAL_FIELDS";
    "PKB_TRANSACTION_FIELDS";
    "PKB_TRANSACTION_STATUS";
    "PKB_TRANSACTION_STATUS_DESC";

    "QIWI_REQUEST_TIMEOUT";
    "VK_REQUEST_TIMEOUT";

    "OSMP_REQUEST_KEY";
    "PKB_QIWIM_QUEUE";
    "PKB_VKMON_QUEUE";
    "PKB_TRANSACTIONS_DONE_KEY";
    "PKB_APPNOTIFICATOR_QUEUE";
    "PKB_RESULT_CODES";
    "PKB_RESULT_CODES_SET";

    "PKB_HACK_TRANSACTIONS_SET";
    "PKB_ANTIHACK_TRANSACTIONS_SET";

    "pkb_get_transaction_id";
    "pkb_parse_pkkey";
    "pkb_normalize_transaction_id";
    "pkb_move_transaction_at_end_of_queue";

    "pkb_get_time_hash";

    "pkb_ping_redis";

    "pkb_get_transaction_status";
    "pkb_add_transaction_to_hackset";
    "pkb_add_transaction_to_antihackset";

    "pkb_get_amounts_from_set";
    "pkb_get_amounts_range";
    "pkb_get_rate";

    "create_application_config_schema";
    "create_paysystem_schema";

    "pkb_send_http_request";

    "pkb_price_equals";
    "pkb_check_price";
    "pkb_tfieldsort_tonumber";
  };

  handler = function()
    local ltn12 = require 'ltn12'
    local PKB_APPLICATION_CONFIG_SECTION = "pk_billing"

    local PKB_ALLOWED_API_FORMATS =
    {
      xml = true;
      json = true;
      luabins = true;
    }

    local QIWI_REQUEST_TIMEOUT = 5
    local VK_REQUEST_TIMEOUT = 5

    --redis keys
    local PKB_HACK_TRANSACTIONS_SET = "hack:transactions"
    local PKB_ANTIHACK_TRANSACTIONS_SET = "antihack:transactions"
    local PKB_TRANSACTIONS_DONE_KEY = "done:app:"
    local PKB_APPNOTIFICATOR_QUEUE = "app-notificator:queue"
    local OSMP_REQUEST_KEY = "osmp_request:"
    local PKB_QIWIM_QUEUE = "qiwi:monitored:transactions"
    local PKB_VKMON_QUEUE = "vk:monitored:transactions"

    local PKB_TIME_INTERVAL = 3600
    local PKB_TRANSACTION_STATUS =
    {
      INVALID = 0;                      -- request invalid
      NOT_FOUND = 1;                    -- not found
      WAITING_CONFIRMATION_BY_APP = 2;  -- waiting confirmation from application
      CONFIRMED_BY_APP = 3;             -- request confirmed by application
      REJECTED_BY_APP = 4;              -- request rejected by application
      CONFIRMED_BY_PAYSYSTEM = 5;       -- request confirmed by payment system
      CLOSED_BY_APP = 6;                -- request accepted by application
      REJECTED_BY_USER = 7;             -- rejected by user from paysystem ui
      FAILED_BY_APP = 8;                -- mark as FAILED by application
      LOST_BY_SPPIP = 9;                -- one of the services are not able to obtain information
      EXPIRED_BY_PAYSYSTEM = 10;        -- expire time of transaction processing by payment system
      LOST_BY_PAYSYSTEM = 11;           -- transaction absent in paysystem DB
      WAITING_FOR_PAYSYSTEM_BILL_CREATION = 12;  -- waiting while paysystem created bill
      PAYSYSTEM_FAILED_TO_CREATE_BILL = 13;      -- paysystem failed to create bill
      ACCOUNT_NOT_FOUND = 14;           -- user account is not found in application, but the SPPIP has a payment on this account
      REJECTED_BY_PAYSYSTEM = 15;       -- transaction rejected by paysystem
                                        -- (insufficient money on user account
                                        --  inside paysystem, or likewise)
    }

    local PKB_TRANSACTION_STATUS_DESC =
    {
      [PKB_TRANSACTION_STATUS.INVALID] = "Invalid";
      [PKB_TRANSACTION_STATUS.NOT_FOUND] = "Not found";
      [PKB_TRANSACTION_STATUS.WAITING_CONFIRMATION_BY_APP] = "Wainting for confirmation";
      [PKB_TRANSACTION_STATUS.CONFIRMED_BY_APP] = "Confirmed by application";
      [PKB_TRANSACTION_STATUS.REJECTED_BY_APP] = "Rejected by application";
      [PKB_TRANSACTION_STATUS.CONFIRMED_BY_PAYSYSTEM] = "Done (confirmed by paysystem)";
      [PKB_TRANSACTION_STATUS.CLOSED_BY_APP] = "Closed by application";
      [PKB_TRANSACTION_STATUS.REJECTED_BY_USER] = "Rejected by user";
      [PKB_TRANSACTION_STATUS.FAILED_BY_APP] = "Marked as failed by app";
      [PKB_TRANSACTION_STATUS.LOST_BY_SPPIP] = "Lost by SPPIP";
      [PKB_TRANSACTION_STATUS.EXPIRED_BY_PAYSYSTEM] = "Expired by payment system";
      [PKB_TRANSACTION_STATUS.LOST_BY_PAYSYSTEM] = "Lost by Paysystem";
      [PKB_TRANSACTION_STATUS.WAITING_FOR_PAYSYSTEM_BILL_CREATION] = "Waiting for paysystem bill creation";
      [PKB_TRANSACTION_STATUS.PAYSYSTEM_FAILED_TO_CREATE_BILL] = "Failed to create paysystem bill";
      [PKB_TRANSACTION_STATUS.ACCOUNT_NOT_FOUND] = "User account is not found in application";
      [PKB_TRANSACTION_STATUS.REJECTED_BY_PAYSYSTEM] = "Rejected by paysystem";
    }

    local PKB_REQUEST_FIELDS =
    {
      "appid";
      "uid";
      "paysystem_id";
      "paysystem_subid";
      "amount";
      "stime";
      "status";
      "payment_id";
      "account_id";
    }
    local PKB_REQUEST_OPTIONAL_FIELDS = tset { "payment_id", "account_id" }
    local PKB_TRANSACTION_FIELDS =
    {
      "appid";
      "uid";
      "paysystem_id";
      "paysystem_subid";
      "payment_id";
      "status";
      "amount";
      "stime";
      "account_id";
    }

    local create_application_config_schema
      = import 'pk-billing/create_application_config_schema.lua'
      {
        'create_application_config_schema'
      }
    local create_paysystem_schema
      = import 'pk-billing/create_paysystem_schema.lua'
      {
        'create_paysystem_schema'
      }

    local PKB_RESULT_CODES = { "ok", "wait", "fail", "duplicate", "account_not_found" }
    local PKB_RESULT_CODES_SET = tset(PKB_RESULT_CODES)

    local pkb_add_transaction_to_hackset = function(api_context, t_id)
      arguments(
          "table", api_context,
          "string", t_id
        )
      local cache = api_context:hiredis():transaction()
      try_unwrap(
          "INTERNAL_ERROR",
          cache:command("sadd", PKB_HACK_TRANSACTIONS_SET, t_id)
        )
    end

    local pkb_add_transaction_to_antihackset = function(api_context, t_id)
      arguments(
          "table", api_context,
          "string", t_id
        )
      local cache = api_context:hiredis():transaction()
      try_unwrap(
          "INTERNAL_ERROR",
           cache:command("sadd", PKB_ANTIHACK_TRANSACTIONS_SET, t_id)
        )
    end

    local pkb_get_transaction_id = function()
      return uuid.new()
    end

    local pkb_parse_pkkey = function(pkkey)
      -- explode primary key on fields
      arguments("string", pkkey)
      local data = split_by_char(pkkey, ':')

      local transaction_id = nil
      if data[1] == "transaction" or data[1] == "request" or data[1] == "application" then
        transaction_id = data[2] or nil
      end

      if not transaction_id then
        return nil, "Incorrect format of primary key: " .. pkkey
      end

      return transaction_id
    end

    local pkb_get_time_hash = function(stime)
      arguments("number", stime)
      return stime - (stime % PKB_TIME_INTERVAL)
    end

    local pkb_get_transaction_status = function(api_context, transaction_id)
      arguments(
          "table", api_context,
          "string", transaction_id
        )

      --search in transactions rdb
      local transaction = api_context:ext("transactions.cache"):try_get(api_context, transaction_id)
      if not transaction or not next(transaction) then
        --search in request queue
        transaction = api_context:ext("request_queue.cache"):try_get(api_context, transaction_id)

        if not transaction or not next(transaction) then
          transaction = { status = PKB_TRANSACTION_STATUS.NOT_FOUND }
        end
      end

      return tonumber(transaction.status)
    end

    local pkb_ping_redis = function(api_context)
      log("[pkb_ping_redis] begin db ping")
      api_context:hiredis():request_queue():command("PING")
      api_context:hiredis():transaction():command("PING")
      api_context:hiredis():settings():command("PING")
      api_context:hiredis():history():command("PING")
      api_context:hiredis():stats():command("PING")
      api_context:hiredis():subtransaction():command("PING")
      log("[pkb_ping_redis] end db ping")
    end

    local pkb_get_amounts_from_set = function(application, project_price, paysystem_id, paysystem_subid)
    -- may return nil
      arguments(
          "table", application,
          "number", project_price,
          "string", paysystem_id
          -- "string", paysystem_subid -- paysystem may be empty (and may be number or string)
        )

      local result = { }
      local paysystem_subid = tostring(paysystem_subid)

      local amounts_set = tgetpath(application, "config", "amounts_set") or { }
      local amounts_to_pay = tgetpath(application, "config", "amounts_to_pay") or { }

      local paysystems_amount = amounts_set[paysystem_id] or amounts_set["default"]
      local paysystems_amount_to_pay = amounts_to_pay[paysystem_id] or amounts_to_pay["default"]

      local currency_price = tgetpath(paysystems_amount, tostring(project_price), tostring(paysystem_subid))
        or tgetpath(paysystems_amount, tostring(project_price), "default")
      local default_price = tgetpath(paysystems_amount_to_pay, tostring(project_price), tostring(paysystem_subid))
        or tgetpath(paysystems_amount_to_pay, tostring(project_price), "default")

      return currency_price, default_price
    end

    local pkb_get_amounts_range = function(application, paysystem_id, paysystem_subid)
    -- may return nil
      arguments(
          "table", application,
          "string", paysystem_id
          -- "string", paysystem_subid -- paysystem may be empty (and may be number or string)
        )
      local amounts = tgetpath(application, "config", "amounts")
      if amounts ~= nil then
        amounts = amounts[paysystem_id] or amounts["default"]
        if paysystem_subid then
          amounts = amounts[tostring(paysystem_subid)]
        end
      end
      return amounts
    end

    local pkb_get_rate = function(application, paysystem_id, paysystem_subid)
    -- may return nil
      arguments(
          "table", application,
          "string", paysystem_id
          -- "string", paysystem_subid -- paysystem may be empty (and may be number or string)
        )

      local rates_config = tgetpath(application, "config", "rates")
      if rates_config ~= nil then
        return rates_config[paysystem_id] and rates_config[paysystem_id][tostring(paysystem_subid)] or rates_config["default"]
      end
      return nil
    end

    local allowed_methods = tset { "POST", "GET" }
    local pkb_send_http_request = function(application, request)
      arguments(
          "table", application,
          "table", request
        )

      local ssl_certificate_path = tgetpath(application, "config", "ssl_certificate_path")
      local ssl_certificate_password = tgetpath(application, "config", "ssl_certificate_password")

      if ssl_certificate_path ~= nil and ssl_certificate_password ~= nil then
        request.ssl_options =
        {
          key = ssl_certificate_path;
          password = ssl_certificate_password;
        }
      end

      return common_send_http_request(request)
    end

    local pkb_normalize_transaction_id = function(transaction_id)
      arguments(
          "string", transaction_id
        )

      local start = transaction_id:find("^transaction:")
      if start == nil then
        transaction_id = "transaction:" .. transaction_id
      end

      return transaction_id
    end

    local pkb_move_transaction_at_end_of_queue = function(api_context, queue, transaction_id)
      arguments(
          "table", api_context,
          "string", queue,
          "string", transaction_id
        )

      local cache = api_context:hiredis():transaction()
      transaction_id = pkb_normalize_transaction_id(transaction_id)

      -- we need to use MULTI_EXEC to don't lose a transaction between LREM and RPUSH
      try_unwrap("INTERNAL_ERROR", cache:append_command("MULTI"))
      try_unwrap("INTERNAL_ERROR", cache:append_command("LREM", queue, 0, transaction_id))
      try_unwrap("INTERNAL_ERROR", cache:append_command("RPUSH", queue, transaction_id))
      try_unwrap("INTERNAL_ERROR", cache:append_command("EXEC"))

      try_unwrap("INTERNAL_ERROR", cache:get_reply()) -- MULTI
      try_unwrap("INTERNAL_ERROR", cache:get_reply()) -- LREM
      try_unwrap("INTERNAL_ERROR", cache:get_reply()) -- RPUSH
      try_unwrap("INTERNAL_ERROR", cache:get_reply()) -- EXEC
    end

    local pkb_price_equals = function(received, saved)
      arguments(
          "number", received,
          "number", saved
        )
      return epsilon_equals(received, saved, 1)
    end
    
    local pkb_check_price = function(api_context, transaction_id, paysystem_amount, transaction_amount)
      arguments(
          "table", api_context,
          "string", transaction_id,
          "number", paysystem_amount,
          "number", transaction_amount
        )
        if paysystem_amount < transaction_amount then
          api_context:ext("history.cache"):try_append(
              api_context,
              transaction_id,
              "[pkb_check_price] saved and received amount not equals. add transaction to hackset"
            )
          pkb_add_transaction_to_hackset(api_context, transaction_id)
          log_error("[pkb_check_price] add transaction to hack-set", transaction_id)
        else
          api_context:ext("history.cache"):try_append(
              api_context,
              transaction_id,
              "[pkb_check_price] saved and received amount not equals. add transaction to antihackset"
            )
          pkb_add_transaction_to_antihackset(api_context, transaction_id)
          log_error("[pkb_check_price] add transaction to antihack-set", transaction_id)
        end
    end

    local pkb_tfieldsort_tonumber = function(t, k)
      arguments(
          "table", t
        )
      assert(k)
      table.sort(
          t,
          function(rhs, lhs)
            return tonumber(rhs[k]) < tonumber(lhs[k])
          end
        )
      return t
    end

  end
}
