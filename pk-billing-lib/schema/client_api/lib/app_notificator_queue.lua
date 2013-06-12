--------------------------------------------------------------------------------
-- app_notificator_queue.lua
-- This file is a part of pk-billing-lib library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------

api:export "lib/appn_queue"
{
  exports =
  {
    -- data
    "APPN_REQUEST_QUEUE_KEY";

    -- methods
    "appn_filter_transactions";
    "appn_create_request";
    "appn_send_request";
    "appn_handle_transactions";
  };

  handler = function()
    local json_util = require 'json.util'
    local json_decode = require 'json.decode'
    local json_decode_util = require 'json.decode.util'
    local json_encode = require 'json.encode'

    local APPN_REQUEST_QUEUE_KEY = "app-notificator:queue"
    local TRANSACTION_VISIBLE_FIELDS = { "stime", "amount", "id", "uid", "paysystem_subid", "paysystem_id" }

    -- TODO: generalize all create_*_request functions, reuse in all services
    -- https://redmine.iphonestudio.ru/issues/2779
    local create_json_request = function(api_context, transactions)
      arguments(
          "table", transactions
        )

      local res = try(
          "INTERNAL_ERROR",
          json_encode
          {
            query =
            {
              version = api_context:game_config().app_api_version;
              method = "payment";
              payments = transactions;
            };
          }
        )
      return res
    end

    local create_luabins_request = function(api_context, transactions)
      arguments(
          "table", transactions
        )
      local payment = try(
          "INTERNAL_ERROR",
          luabins.save
          {
            query =
            {
              version = api_context:game_config().app_api_version;
              method = "payment";
              payments = transactions;
            };
          }
        )
      return payment
    end

    local create_xml_request = function(api_context, transactions)
      arguments(
          "table", transactions
        )

      local cat, concat = make_concatter()

      cat [[<?xml version="1.0" encoding="UTF-8"?>
    <query version="]] (htmlspecialchars(api_context:game_config().app_api_version)) [[" method="payment">
      <payments>]]
      for i = 1, #transactions do
        local payment = transactions[i]
        cat [[
        <payment stime="]] (htmlspecialchars(payment.stime))
          [[" amount="]] (htmlspecialchars(payment.amount)) [["
             paysystem_subid="]] (htmlspecialchars(payment.paysystem_subid))
          [[" paysystem_id="]] (htmlspecialchars(payment.paysystem_id)) [[">
           <id>]]
        cdata_cat(cat, payment.id)
        cat [=[</id>
           <uid>]=]
        cdata_cat(cat, payment.uid)
        cat [=[</uid>
        </payment>
    ]=]
      end
      cat [[  </payments>
    </query>]]
      return concat()
    end

    local REQUESTS_HANDLERS =
    {
      [JSON_REQUEST_FORMAT] = create_json_request;
      [XML_REQUEST_FORMAT] = create_xml_request;
      [LUABINS_REQUEST_FORMAT] = create_luabins_request;
    }

    local appn_create_request = function(api_context, api_format, transactions)
      arguments(
          "table", api_context,
          "string", api_format,
          "table", transactions
        )

      api_format = api_format:lower()
      if not ALLOWED_REQEUST_FORMAT[api_format] then
        return nil, "Unknown format: " .. api_format
      end

      return REQUESTS_HANDLERS[api_format](api_context, transactions)
    end

    local appn_filter_transactions = function(transactions)
      arguments(
          "table", transactions
        )
      local res, ids = { }, { }
      for i = 1, #transactions do
        local transaction = transactions[i]
        transaction.status = tonumber(transaction.status)
        if transaction.status ~= PKB_TRANSACTION_STATUS.CONFIRMED_BY_PAYSYSTEM then
          log_error("[appn_filter_transactions] transaction", transaction.id, " has incorrect status:", PKB_TRANSACTION_STATUS_DESC[transaction.status])
        else
          local filtered = tfilterkeylist(transaction, TRANSACTION_VISIBLE_FIELDS)

          ids[#ids + 1] = filtered.id
          res[#res + 1] = filtered
        end
      end

      return res, ids
    end

    local transactions_mapper = function(k, v)
      return v.id, v
    end

    local appn_send_request = function(api_context, application, request)
      arguments(
          "table", api_context,
          "table", application,
          "string", request
        )

      local decode_options = json_util.merge(
          {
            object =
            {
              setObjectKey = json_decode_util.setObjectKeyForceNumber;
            };
          },
          json_decode.simple
        )

      local url = application.api.urls.payment
      if application.api.use_url_query == true then
        url = url .. "?method=payment"
      end

      local response_body, err = pkb_send_http_request(
          application,
          {
            url = url;
            method = "POST";
            request_body = request;
            headers =
            {
              ["User-Agent"] = api_context:game_config().user_agent;
            };
          }
        )
      if not response_body then
        log("[send_request] request to url: ", url, "\nrequest body: ", request, "\nresponse: ", response_body)
        return fail("EXTERNAL_ERROR", err)
      end
      -- use pcall for correct handle assert in json_decode function
      local ok, response = pcall(json_decode, response_body,  decode_options)
      if not ok then
        local err = "parse error: " .. response
        log("[send_request] request to url: ", url, "\nrequest body: ", request, "\nfailed to parse: ", response_body)
        return fail("PARSE_ERROR", err)
      elseif response == nil or response.error ~= nil or response.ok == nil then
        local err = "UNKNOWN"
        if response.error then
          err = response.error.id or "UNKNOWN"
        end
        log("[send_request] request to url: ", url, "\nrequest body: ", request, "\nresponse: ", response_body)
        return fail("EXTERNAL_ERROR", "[send_request] application returned error: " .. err)
      end
      if not response.ok.payments then
        log("[send_request] request to url: ", url, "\nrequest body: ", request, "\nresponse: ", response_body)
        return fail("EXTERNAL_ERROR", "[send_request] incorrect format of application response")
      end

      return response.ok.payments
    end

    local appn_handle_response = function(api_context, appid, ids, transactions, response, params)
      arguments(
          "table", api_context,
          "string", appid,
          "table", ids,
          "table", transactions,
          "table", response,
          "table", params
        )
      local ids = tset(ids)

      local result_codes = { }
      for i = 1, #PKB_RESULT_CODES do
        result_codes[PKB_RESULT_CODES[i]] = { }
      end

      for i = 1, #response do
        local payment = response[i]

        if payment.id == nil or payment.result_code == nil then
          log_error("[handle_response] incorrect response format", payment)
        else
          local res_code = tostring(payment.result_code):lower()
          if not PKB_RESULT_CODES_SET[res_code] then
            log_error("[handle_response] unknown result_code", payment)
          else
            if not ids[payment.id] then
              log_error("[handle_response] applicaiton reported about not requested payment: ", payment)
            else
              result_codes[res_code][#result_codes[res_code] + 1] = payment.id
              ids[payment.id] = nil
            end
          end
        end
      end

      for id, _ in pairs(ids) do
        log_error("[handle_response] application not reported about transaction: ", id)
        result_codes["wait"][#result_codes["wait"] + 1] = id
      end

      local cache = api_context:hiredis():transaction()
      local key = PKB_TRANSACTIONS_DONE_KEY .. appid

      for i = 1, #result_codes.wait do
        local id = result_codes.wait[i]

        try_unwrap(
            "INTERNAL_ERROR",
            cache:command("SADD", key, "transaction:" .. id)
          )
        api_context:ext("history.cache"):try_append(api_context, id, "[app_notificator] app response: WAIT")
        log("[handle_response] wait: ", "transaction:" .. id)
      end
      for i = 1, #result_codes.fail do
        local id = result_codes.fail[i]
        try_unwrap(
            "INTERNAL_ERROR",
            cache:command("SREM", key, "transaction:" .. id)
          )
        local src_t = tclone(transactions[id])
        transactions[id].status = PKB_TRANSACTION_STATUS.FAILED_BY_APP
        api_context:ext("transactions.cache"):try_set(api_context, transactions[id], src_t)
        api_context:ext("history.cache"):try_append(api_context, id, "[app_notificator] app response: FAIL")
        log("[handle_response] fail: ", "transaction:" .. id)
      end
      for i = 1, #result_codes.ok do
        local id = result_codes.ok[i]
        try_unwrap(
            "INTERNAL_ERROR",
            cache:command("SREM", key, "transaction:" .. id)
          )
        local src_t = tclone(transactions[id])
        transactions[id].status = PKB_TRANSACTION_STATUS.CLOSED_BY_APP
        api_context:ext("transactions.cache"):try_set(api_context, transactions[id], src_t)
        api_context:ext("history.cache"):try_append(api_context, id, "[app_notificator] app response: OK")
        log("[handle_response] ok: ", "transaction:" .. id)
      end
      for i = 1, #result_codes.duplicate do
        local id = result_codes.duplicate[i]
        try_unwrap(
            "INTERNAL_ERROR",
            cache:command("SREM", key, "transaction:" .. id)
          )
        api_context:ext("history.cache"):try_append(api_context, id, "[app_notificator] app response: DUPLICATE")
        if params.duplicate_status then
          local src_t = tclone(transactions[id])
          transactions[id].status = params.duplicate_status
          api_context:ext("transactions.cache"):try_set(api_context, transactions[id], src_t)
        end
        log("[handle_response] duplicate: ", "transaction:" .. id)
      end
      for i = 1, #result_codes.account_not_found do
        local id = result_codes.account_not_found[i]
        try_unwrap(
            "INTERNAL_ERROR",
            cache:command("SREM", key, "transaction:" .. id)
          )
        local src_t = tclone(transactions[id])
        transactions[id].status = PKB_TRANSACTION_STATUS.ACCOUNT_NOT_FOUND
        api_context:ext("transactions.cache"):try_set(api_context, transactions[id], src_t)
        api_context:ext("history.cache"):try_append(api_context, id, "[app_notificator] app response: ACCOUNT_NOT_FOUND")
        log("[handle_response] account_not_found: ", "transaction:" .. id)
      end
    end

    local appn_handle_transactions = function(api_context, application, transactions, params)
      arguments(
          "table", api_context,
          "table", application,
          "table", transactions
        )

      local f_transactions, ids = appn_filter_transactions(transactions)
      if #f_transactions == 0 or #ids == 0 then
        return fail("INTERNAL_ERROR", "[appn_handle_transactions] transactions list is empty")
      end

      local request = appn_create_request(api_context, application.api.format, f_transactions)
      local app_response, err = call(appn_send_request, api_context, application, request)
      if app_response == nil then
        log("[handle_transactions] add transactions to wait list: ", ids)

        local cache = api_context:hiredis():transaction()
        local key = PKB_TRANSACTIONS_DONE_KEY .. application.id
        for i = 1, #ids do
          local id = ids[i]
          api_context:ext("history.cache"):try_append(api_context, id, "[app_notificator][handle_transactions] error while send request to app: " .. err)
          try_unwrap(
              "INTERNAL_ERROR",
              cache:command("SADD", key, "transaction:" .. id)
            )
        end
      else
        transactions = tmap_kv(transactions_mapper, transactions)
        appn_handle_response(api_context, application.id, ids, transactions, app_response, params or { })
      end
    end
  end;
}

api:extend_context "app_notificator.queue" (function()

  local get_app_transactions = function(self, api_context, appid)
    method_arguments(
        self,
        "table", api_context,
        "string", appid
      )
    local cache = api_context:hiredis():transaction()

    local key = PKB_TRANSACTIONS_DONE_KEY .. appid
    local transaction_ids = try_unwrap(
        "INTERNAL_ERROR",
        cache:command("SMEMBERS", key)
      )

    if #transaction_ids == 0 then
      return { }
    end

    local transactions = { }
    for i = 1, #transaction_ids do
      local transaction_id = transaction_ids[i]

      if transaction_id == nil then
        log_error("get_app_transactions: nil value for t_id in list ", i, transaction_ids)
      else
        local transaction = api_context:ext("transactions.cache"):try_get(api_context, transaction_id)
        transaction.transaction_id = pkb_parse_pkkey(transaction_id)
        transaction.id = pkb_parse_pkkey(transaction_id)
        transactions[#transactions + 1] = transaction
      end
    end

    return transactions
  end

  local try_pop = function(self, api_context, timeout)
    method_arguments(
        self,
        "table", api_context,
        "number", timeout
      )
    local cache = api_context:hiredis():transaction()

    local data = try_unwrap(
        "INTERNAL_ERROR",
        cache:command("BLPOP", APPN_REQUEST_QUEUE_KEY, timeout)
      )

    --TODO: sometime in data "0", need to understand
    if data == hiredis.NIL or not is_table(data) then
      return nil, "App-notificator queue are empty"
    end

    local key, value = data[1], data[2]
    local transaction_id, err = pkb_parse_pkkey(value)
    if not transaction_id then
      log_error("blpop_transaction: ", err)
      return nil, err
    end

    log("blpop_transaction: ", transaction_id)

    local transaction = api_context:ext("transactions.cache"):try_get(api_context, transaction_id)
    if not next(transaction) then
      log("blpop_transaction: lost transaction: ", value)

      --set LOST status
      try_unwrap(
          "INTERNAL_ERROR",
          cache:command("HMSET", "transaction:" .. transaction_id, "status", PKB_TRANSACTION_STATUS.LOST_BY_SPPIP)
        )

      return nil, "Lost transaction: " .. value
    end
    transaction.transaction_id = transaction_id --for try_set_transaction
    transaction.id = transaction_id -- for create_*_request

    return value, transaction
  end

  local factory = function()

    return
    {
      get_app_transactions = get_app_transactions;

      try_pop = try_pop;
    }
  end

  -- TODO: its not work in standalone-services becuase they dont support zmq.
  -- https://redmine.iphonestudio.ru/issues/1472
  local system_action_handlers = { }

  return
  {
    factory = factory;
    system_action_handlers = system_action_handlers;
  }
end)
