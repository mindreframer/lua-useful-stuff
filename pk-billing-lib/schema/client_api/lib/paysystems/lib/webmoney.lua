--------------------------------------------------------------------------------
-- webmoney.lua
-- This file is a part of pk-billing-lib library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------

api:export "lib/paysystems/lib/webmoney"
{
  exports =
  {
    --data
    "WM_ERROR_CODES";
    "wm_saved_fields";
    "WM_ALLOWED_PAYMENT_STATUSES";
    "WM_CLOSED_PAYMENTS";

    --methods
    "wm_build_response";
    "wm_check_fields";
    "wm_create_hash";
  };

  handler = function()
    local WM_ERROR_CODES =
    {
      ["OK"] = "YES";
      ["APPLICATION_NOT_FOUND"] = "NO";
      ["INTERNAL_ERROR"] = "NO";
      ["INCORRECT_MODE"] = "NO";
      ["UNKNOWN_WALLET"] = "NO";
      ["INCORRECT_STATUS"] = "NO";
      ["BAD_INPUT"] = "NO";
      ["INCORRECT_HASH"] = "NO";
      ["DUPLICATE_REQUEST"] = "YES";
    }
    local wm_request_fields =
    {
      ["payment"] =
      {
        "LMI_SYS_INVS_NO";
        "LMI_SYS_TRANS_NO";
        "LMI_HASH";
        "LMI_SYS_TRANS_DATE";
      };
    }
    local wm_hash_fields =
    {
      "LMI_PAYEE_PURSE";
      "LMI_PAYMENT_AMOUNT";
      "LMI_PAYMENT_NO";
      "LMI_MODE";
      "LMI_SYS_INVS_NO";
      "LMI_SYS_TRANS_NO";
      "LMI_SYS_TRANS_DATE";
      "LMI_SECRET_KEY";
      "LMI_PAYER_PURSE";
      "LMI_PAYER_WM";
    }
    local wm_saved_fields =
    {
      "LMI_PAYEE_PURSE";
      "LMI_PAYER_PURSE";
      "LMI_PAYER_WM";
      "LMI_SYS_INVS_NO";
      "LMI_SYS_TRANS_NO";
      "LMI_SYS_TRANS_DATE";
    }
    local WM_ALLOWED_PAYMENT_STATUSES = tset
    {
      PKB_TRANSACTION_STATUS.CONFIRMED_BY_APP;
      PKB_TRANSACTION_STATUS.CONFIRMED_BY_PAYSYSTEM;
      PKB_TRANSACTION_STATUS.CLOSED_BY_APP;
    }
    local WM_CLOSED_PAYMENTS = tset
    {
      PKB_TRANSACTION_STATUS.CONFIRMED_BY_PAYSYSTEM;
      PKB_TRANSACTION_STATUS.CLOSED_BY_APP;
    }

    local wm_build_response = function(api_context, code, request, history)
      arguments(
          "table", api_context,
          "string", code,
          "table", request,
          "table", history
        )

      api_context:ext("history.cache"):try_append(
          api_context,
          request.transaction_id,
          history
        )
      code = WM_ERROR_CODES[code] or code

      return html_response(code)
    end

    local wm_check_fields = function(request_type, request)
      arguments(
          "string", request_type,
          "table", request
        )

      if not wm_request_fields[request_type] then
        return nil, "Unknown request type: " .. tostring(request_type)
      end

      for i = 1, #wm_request_fields[request_type] do
        local key = wm_request_fields[request_type][i]
        if not request[key] then
          return nil, "Field absent in request: " .. key
        end
      end

      return request
    end

    local wm_create_hash = function(request)
      arguments(
          "table", request
        )

      local hash_fields = { }
      for i = 1, #wm_hash_fields do
        local key = wm_hash_fields[i]
        if not request[key] then
          return nil, "Field absent in request: " .. key
        end

        hash_fields[#hash_fields + 1] = request[key]
      end

      hash_fields = table.concat(hash_fields)
      return md5.sumhexa(hash_fields):upper()
    end
  end;
}

api:extend_context "webmoney.cache" (function()
  local try_set = function(self, api_context, request)
    method_arguments(
        self,
        "table", api_context,
        "table", request
      )

    local transaction_id = request.transaction_id

    local transaction = { }
    for i = 1, #wm_saved_fields do
      local field = wm_saved_fields[i]

      if request[field] then
        transaction[field] = request[field]
      end
    end

    api_context:ext("subtransactions.cache"):try_set(
        api_context,
        transaction_id,
        transaction
      )
  end

  local factory = function()
    return
    {
      try_set = try_set;
    }
  end

  -- TODO: its not work in standalone-services becuase they dont support zmq.
  -- https://redmine.iphonestudio.ru/issues/1472
  local system_action_handlers =
  {
    ["webmoney.cache:set"] = function(api_context, request)
      spam("webmoney.cache:set")

      -- TODO: LAZY HACK. This currently updates redis data
      --       once for each fork. It should do it once per save!
      api_context:ext("webmoney.cache"):try_set(api_context, request)

      spam("/webmoney.cache:set")

      return true
    end;
  }

  return
  {
    factory = factory;
    system_action_handlers = system_action_handlers;
  }
end)
