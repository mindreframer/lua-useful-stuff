--------------------------------------------------------------------------------
-- osmp.lua
-- This file is a part of pk-billing-lib library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------

api:export "lib/paysystems/lib/osmp"
{
  exports =
  {
    "OSMP_ERROR_CODES";
    "OSMP_ALLOWED_PAYMENT_STATUS";
    "OSMP_CLOSED_PAYMENTS";

    "osmp_save_transaction";
    "osmp_search_transaction";

    "osmp_create_response";
    "osmp_build_response";

    "osmp_blpop_request";
    "osmp_rm_request";
  };

  handler = function()
    local OSMP_ERROR_CODES =
    {
      ["OK"] = 0;
      ["BAD_INPUT"] = 300;
      ["INCORRECT_COMMAND"] = 300;
      ["TRANSACTION_NOT_FOUND"] = 300;
      ["FATAL_ERROR"] = 300;
      ["ACCOUNT_NOT_FOUND"] = 5;
      ["FAIL"] = 300;
      ["INTERNAL_ERROR"] = 1;
      ["WAIT_RESULT"] = 1;
      ["INCORRECT_ACCOUNT_FORMAT"] = 4;
    }
    local OSMP_ALLOWED_PAYMENT_STATUS =
    {
       PKB_TRANSACTION_STATUS.CONFIRMED_BY_APP;
       PKB_TRANSACTION_STATUS.REJECTED_BY_APP;
       PKB_TRANSACTION_STATUS.CONFIRMED_BY_PAYSYSTEM;
       PKB_TRANSACTION_STATUS.CLOSED_BY_APP;
    }
    local OSMP_CLOSED_PAYMENTS = tset
    {
      PKB_TRANSACTION_STATUS.CONFIRMED_BY_PAYSYSTEM;
      PKB_TRANSACTION_STATUS.CLOSED_BY_APP;
    }
    local OSMP_REQUEST_TIMEOUT = 20
    local OSMP_TXNIDS = "qiwi:txn_id:transactions:"

    local osmp_save_transaction = function(api_context, appid, request)
      arguments(
          "table", api_context,
          "string", appid,
          "table", request
        )
      local cache = api_context:hiredis():transaction()

      if not request.payment_id or not request.transaction_id then
       return nil, "Not enough data"
      end

      local res = try_unwrap(
          "INTERNAL_ERROR",
          cache:command(
              "HMSET",
              OSMP_TXNIDS .. appid,
              "txn:" .. request.payment_id,
              request.transaction_id
            )
        )
      return tostring(res) == "OK"
    end

    local osmp_search_transaction = function(api_context, appid, txn_id)
      arguments(
          "table", api_context,
          "string", appid,
          "string", txn_id
        )
      local cache = api_context:hiredis():transaction()

      local transaction_id = try_unwrap(
          "INTERNAL_ERROR",
          cache:command("HGET", OSMP_TXNIDS .. appid, "txn:" .. txn_id)
        )
      if transaction_id == hiredis.NIL then
        return nil
      end

      local transaction = api_context:ext("transactions.cache"):try_get(
          api_context,
          transaction_id
        )
      if not tisempty(transaction) then
        transaction.transaction_id = transaction_id
      else
        transaction = nil
      end
      return transaction, transaction_id ~= hiredis.NIL
    end

    local osmp_create_response = function(code, request)
      local cat, concat = make_concatter()
      cat [[<?xml version="1.0" encoding="UTF-8"?>
<response>
<osmp_txn_id>]]
      cat (htmlspecialchars(request.txn_id and tostring(request.txn_id) or ""))
      cat [[</osmp_txn_id>
<prv_txn>]]
      cat (htmlspecialchars(request.transaction_id and tostring(request.transaction_id) or ""))
      cat [[</prv_txn>
<sum>]]
      cat (htmlspecialchars(request.sum and tostring(request.sum) or "")) [[</sum>
<result>]]
      cat (htmlspecialchars(tostring(code))) [[</result>
<comment>]]
      cat (htmlspecialchars(request.comment or "")) [[</comment>
</response>]]

      return concat();
    end

    local osmp_build_response = function(code, request)
      arguments(
          "string", code,
          "table", request
        )

      log(
          "[qiwi/payment] action:",
          request.command or "",
          ";result:",
          code,
          ";txn_id:",
          request.txn_id
        )

      code = OSMP_ERROR_CODES[code] or code
      local body = osmp_create_response(code, request)
      return xml_response(body)
    end

    local osmp_blpop_request = function(api_context, request_id)
      arguments(
          "table", api_context,
          "string", request_id
        )

      local cache = api_context:hiredis():transaction()
      local key = OSMP_REQUEST_KEY .. request_id

      local data = try_unwrap(
          "INTERNAL_ERROR",
          cache:command("BLPOP", key, OSMP_REQUEST_TIMEOUT)
        )

      if data == hiredis.NIL then
        return false
      end

      local key, transaction_id = data[1], data[2]
      local transaction = api_context:ext("transactions.cache"):try_get(
          api_context,
          transaction_id
        )

      return transaction
    end

    local osmp_rm_request = function(api_context, request_id)
      arguments(
          "table", api_context,
          "string", request_id
        )

      local cache = api_context:hiredis():transaction()
      request_id = pkb_parse_pkkey(request_id) or request_id
      local key = OSMP_REQUEST_KEY .. request_id

      try_unwrap("INTERNAL_ERROR", cache:command("DEL", key))
    end
  end;
}
