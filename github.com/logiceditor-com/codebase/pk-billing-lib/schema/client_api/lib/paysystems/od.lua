--------------------------------------------------------------------------------
-- od.lua
-- This file is a part of pk-billing-lib library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------

api:export "lib/paysystems/od"
{
  exports =
  {
    -- methods
    "od_error_handler";
    "od_response_handler";

    "od_check";
    "od_payment";
  };

  handler = function()
    local OD_CHECK_ALLOWED_STATUS = tset
    {
      PKB_TRANSACTION_STATUS.CONFIRMED_BY_APP;
      PKB_TRANSACTION_STATUS.CONFIRMED_BY_PAYSYSTEM;
      PKB_TRANSACTION_STATUS.CLOSED_BY_APP;
    }
    local OD_PAYMENT_ALLOWED_STATUS = tset
    {
      PKB_TRANSACTION_STATUS.CONFIRMED_BY_APP;
      PKB_TRANSACTION_STATUS.CONFIRMED_BY_PAYSYSTEM;
      PKB_TRANSACTION_STATUS.CLOSED_BY_APP;
    }

    local od_response_handler = function(body)
      return xml_response(body)
    end

    local od_error_handler = function(code, api_context, request_type)
      if request_type == OD_CHECK_REQUEST then
        code = OD_RESPONSE_CODE_NO
        return od_create_check_response(code)
      elseif request_type == OD_PAYMENT_REQUEST then
        local request = api_context:post_request()
        return od_create_payment_response(code, request)
      end
    end

    -- example of input parameters for check script
    --   api:input
    --   {
    --     input:PAYMENT_ID "userid";
    --     input:TEXT "key";
    --   };
    local od_check = function(api_context, application, request)
      arguments(
          "table", api_context,
          "table", application,
          "table", request
        )

      local hash = od_create_hash(
          "check",
          request,
          application.config['od_shop_password']
        )
      if trim(hash) ~= trim(request.key) then
        log_error("[od/check] incorrect key of request: ", hash, "/", request.key)
        return od_build_response("check", OD_RESPONSE_CODE_NO, request)
      end

      local transaction = api_context:ext("transactions.cache"):try_get(
          api_context,
          request.userid
        )

      if not next(transaction) then
        log_error("[od/check] transaction ", request.userid, " not found ")
        return od_build_response("check", OD_RESPONSE_CODE_NO, request)
      end

      api_context:ext("history.cache"):try_append(
          api_context,
          request.userid,
          " Check request: " .. tstr(request)
        )

      transaction.status = tonumber(transaction.status)

      if not OD_CHECK_ALLOWED_STATUS[transaction.status] then
        log_error(
            "[od/check] transaction ",
            request.userid,
            " have incorrect status ",
            transaction.status
          )
        api_context:ext("history.cache"):try_append(
            api_context,
            request.userid,
            "[check] incorrect status " .. tostring(transaction.status)
          )
        return od_build_response("check", OD_RESPONSE_CODE_NO, request)
      end

      log("[od/check] transaction checked successfully: ", request.userid)
      api_context:ext("history.cache"):try_append(
          api_context,
          request.userid,
          "[check] transaction checked successfully"
        )
      return od_build_response("check", OD_RESPONSE_CODE_YES, request)
    end

    -- example of input parameters for payment script
    --   api:input
    --   {
    --     input:TEXT "amount";
    --     input:PAYMENT_ID "userid";
    --     input:TEXT "paymentid";
    --     input:TEXT "key";
    --     input:TEXT "paymode";
    --   };
    local od_payment = function(api_context, application, request)
      arguments(
          "table", api_context,
          "table", application,
          "table", request
        )

      local hash = od_create_hash(
          "payment",
          request,
          application.config['od_shop_password']
        )
      if trim(hash) ~= trim(request.key) then
        log_error("[od/payment] incorrect key of request: ", hash, "/", request.key)
        return od_build_response("payment", OD_RESPONSE_CODE_NO, request)
      end

      local od_amount = tonumber(request.amount) * 100

      local transaction = api_context:ext("transactions.cache"):try_get(
          api_context,
          request.userid
        )
      transaction.transaction_id = request.userid

      if not next(transaction) then
        log_error("[od/payment] transaction ", request.userid, " not found ")
        return od_build_response("payment", OD_RESPONSE_CODE_NO, request)
      end

      api_context:ext("history.cache"):try_append(
          api_context,
          request.userid,
          " Payment request: " .. tstr(request)
        )

      local transaction_status = tonumber(transaction.status)

      if not OD_PAYMENT_ALLOWED_STATUS[transaction_status] then
        log_error(
            "[od/payment] transaction ",
            request.userid,
            " have incorrect status ",
            transaction.status
          )
        api_context:ext("history.cache"):try_append(
            api_context,
            request.userid,
            "[payment] incorrect status" .. tstr(request)
          )
        return od_build_response("payment", OD_RESPONSE_CODE_NO, request)
      end
      if
        transaction_status == PKB_TRANSACTION_STATUS.CONFIRMED_BY_PAYSYSTEM
        or transaction_status == PKB_TRANSACTION_STATUS.CLOSED_BY_APP
      then
        log("[od/payment] duplicate request for transaction ", request.userid)
        api_context:ext("history.cache"):try_append(
            api_context,
            request.userid,
            "[payment] duplicate request (code = YES)"
          )
        return od_build_response("payment", OD_RESPONSE_CODE_YES, request)
      end

      local tamount = tonumber(transaction.amount)
      if not pkb_price_equals(od_amount, tamount) then
        log_error(
            "[od/payment] saved and received amounts are not equals ",
            tamount,
            "/",
            od_amount,
            transaction.transaction_id
          )
        pkb_check_price(
            api_context,
            transaction.transaction_id,
            od_amount,
            tamount
          )
        transaction.amount = od_amount
      end
      if
        transaction.paysystem_id ~= OD_PAYSYSTEM_ID
        or transaction.appid ~= application.id
      then
        log_error(
            "[od/payment] saved and received data not equals ",
            transaction,
            request
          )
        api_context:ext("history.cache"):try_append(
            api_context,
            request.userid,
            "[payment] saved and received data not equals"
          )
        return od_build_response("payment", "INCORRECT_DATA", request)
      end

      local src_t = tclone(transaction)

      transaction.payment_id = request.paymentid
      transaction.status = PKB_TRANSACTION_STATUS.CONFIRMED_BY_PAYSYSTEM
      transaction.pay_stime = os.time()
      transaction.paysystem_subid = request.paymode

      api_context:ext("transactions.cache"):try_set(
          api_context,
          transaction,
          src_t
        )

      log("[od/payment] transaction payment successfully: ", request.userid)
      api_context:ext("history.cache"):try_append(
          api_context,
          request.userid,
          "[payment] transaction payment successfully"
        )
      return od_build_response("payment", OD_RESPONSE_CODE_YES, request)
    end
  end;
}
