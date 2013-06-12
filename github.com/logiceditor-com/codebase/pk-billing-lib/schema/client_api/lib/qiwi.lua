--------------------------------------------------------------------------------
-- qiwi.lua
-- This file is a part of pk-billing-lib library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------

api:export "lib/qiwi"
{
  exports =
  {
    -- data
    "QIWI_REQUEST_TYPES";

    -- methods
    "qw_create_request";
    "qw_send_request";
  };

  handler = function()
    require "lxp.lom"

    local QIWI_REQUEST_TYPES = tflip_inplace
    {
      CREATE_BILL = 30;           -- request for create bill
      GET_BILLS_STATUSES = 33;    -- request for get statuses of bills
    }

    local qw_create_request = function(application, request_type, request_body)
      arguments(
          "table", application,
          "number", request_type,
          "string", request_body
        )

      application.config = application.config or { }
      if not application.config["qiwi_provider_id"] or not application.config["qiwi_provider_passwd"] then
        return fail("QIWI_CONFIG_MISMATCH", "[qw_create_request] QIWI provider data absent in config for app = " .. tostring(application.id))
      end

      if not QIWI_REQUEST_TYPES[request_type] then
        return fail("UNSUPPORTED_REQUEST_TYPE", "[qw_create_request] Unsupported qiwi request-type: " .. tostring(request_type))
      end

      local cat, concat = make_concatter()
      -- request_body content is already escaped
      cat [[<?xml version="1.0" encoding="utf-8"?>
<request>
  <protocol-version>4.0</protocol-version>
  <request-type>]] (htmlspecialchars(request_type)) [[</request-type>
  <terminal-id>]] (htmlspecialchars(application.config["qiwi_provider_id"]))
    [[</terminal-id>
  <extra name="password">]] (htmlspecialchars(
      application.config["qiwi_provider_passwd"]
    ))
    [[</extra>
]] (request_body)  [[
</request>]]

      return concat()
    end

    local qw_send_request = function(api_context, request_body)
      arguments(
          "table", api_context,
          "string", request_body
        )

      if #request_body == 0 then
        return fail("INTERNAL_ERROR", "[qw_send_request] Attempt to send empty request")
      end

      local response_body = try(
          "EXTERNAL_ERROR",
          common_send_http_request(
              {
                url = QIWI_API_URL;
                method = "POST";
                request_body = request_body;
                headers =
                {
                  ["User-Agent"] = api_context:game_config().user_agent;
                };
              }
            )
        )

      local parsed_xml = try(
          "INTERNAL_ERROR",
          lxp.lom.parse(response_body)
        )
      local response = try(
          "INTERNAL_ERROR",
          xml_convert_lom(parsed_xml)
        )

      local result_code = tonumber(tgetpath(response, 'response', 'result-code', 1, 'value'))
      if result_code == nil or result_code ~= 0 then
        log_error("qiwi error-code: ", result_code, "; request: ", request_body)
        return fail("EXTERNAL_ERROR", "Get error-code from qiwi: " .. tostring(result_code))
      end

      return result_code, response
    end

  end
}

api:extend_context "qiwi.api" (function()
  local create_bill = function(self, api_context, transaction, application)
    method_arguments(
        self,
        "table", api_context,
        "table", transaction,
        "table", application
      )

    local qiwi_amount = tostring(transaction.amount / 100)
    local txn_id = call(pkb_parse_pkkey, transaction.transaction_id)

    local ltime = application.config["transaction_ttl"] or (PKB_DEFAULT_TRANSACTION_TTL and 1 or 0)
    local create_agt = application.config["qiwi_use_create_agt"] or (QIWI_DEFAULT_USE_CREATE_AGT and 1 or 0)
    local alarm_sms = application.config["qiwi_use_alarm_sms"] or (QIWI_DEFAULT_USE_ALARM_SMS and 1 or 0)
    local accept_call  = alarm_sms and 0 or (application.config["qiwi_use_accept_call"] or (QIWI_DEFAULT_USE_ACCEPT_CALL and 1 or 0))

    -- xml request to qiwi for create new account in qiwi-wallet
    -- create-agt = 1 => we create agent if agent is absent
    -- ALARM_SMS = 0 - we dont use sms notification
    -- ACCEPT_CALL = 0 - we dont use call-notification
    local cat, concat = make_concatter()
    cat [[
    <extra name="txn-id">]] (htmlspecialchars(txn_id)) [[</extra>
    <extra name="to-account">]] (htmlspecialchars(transaction.account_id)) [[</extra>
    <extra name="amount">]] (htmlspecialchars(qiwi_amount)) [[</extra>
    <extra name="create-agt">]] (htmlspecialchars(create_agt)) [[</extra>
    <extra name="ltime">]] (htmlspecialchars(ltime)) [[</extra>
    <extra name="ALARM_SMS">]] (htmlspecialchars(alarm_sms)) [[</extra>
    <extra name="ACCEPT_CALL">]] (htmlspecialchars(accept_call)) [[</extra>
]]

    local xml = concat()
    local request_body, error_text = call(qw_create_request, application, QIWI_REQUEST_TYPES.CREATE_BILL, xml)
    if request_body ~= nil then
      local res, err = call(qw_send_request, api_context, request_body)
      if res ~= nil then
        return res
      end
      error_text = err
    end
    log_error("[qiwi.api:create_bill] error:", error_text)
    return nil, error_text
  end -- create_bill

  local get_bills_statuses = function(self, api_context, transactions, application)
    method_arguments(
        self,
        "table", api_context,
        "table", transactions,
        "table", application
      )

    local cat, concat = make_concatter()
    cat [[
    <bills-list>
]]
    for i = 1, #transactions do
      local tid, err = call(pkb_parse_pkkey, transactions[i])
      if tid ~= nil then
        cat [[
      <bill txn-id="]] (htmlspecialchars(tid)) [[" />
]]
      else
        log_error("[qiwi.api:get_bills_statuses] error: ", err)
      end
    end
    cat [[
    </bills-list>
]]

    local xml = concat()
    local request_body, error_text = call(qw_create_request, application, QIWI_REQUEST_TYPES.GET_BILLS_STATUSES, xml)
    if request_body ~= nil then
      local result_code, bills = call(qw_send_request, api_context, request_body)
      if result_code ~= nil then
        return call(tgetpath, bills, 'response', 'bills-list', 1, 'bill')
      end
      error_text = bills
    end
    log_error("[qiwi.api:get_bills_statuses] error:", error_text)
    return nil, error_text
  end -- get_bills_statuses

  local factory = function()
    return
    {
      create_bill = create_bill;
      get_bills_statuses = get_bills_statuses;
    }
  end

  -- TODO: its not work in standalone-services becuase they dont support zmq.
  -- https://redmine.iphonestudio.ru/issues/1472
  local system_action_handlers =
  {
  }

  return
  {
    factory = factory;
    system_action_handlers = system_action_handlers;
  }
end)
