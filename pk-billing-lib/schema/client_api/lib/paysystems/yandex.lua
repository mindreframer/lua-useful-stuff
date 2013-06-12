--------------------------------------------------------------------------------
-- yandex.lua
-- This file is a part of pk-billing-lib library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------

api:export "lib/paysystems/yandex"
{
  exports =
  {
    -- data
    "YANDEX_CHECK_REQUEST";
    "YANDEX_PAYMENT_REQUEST";

    -- methods
    "yandex_response_handler";
    "yandex_error_handler";

    "yandex_check";
    "yandex_payment";
  };

  handler = function()
    local YANDEX_CHECK_REQUEST = "check"
    local YANDEX_PAYMENT_REQUEST = "payment"

    local yandex_response_handler = function(body)
      return xml_response(body)
    end

    local yandex_error_handler = function(code, api_context, request_type)
      local request = api_context:post_request()

      if request.customerNumber ~= nil then
        api_context:ext("history.cache"):try_append(
            api_context,
            request.customerNumber,
            request_type .. " request: result code: " .. tostring(code)
          )
      end

      code = YA_ERROR_CODES[code] or code
      return ya_create_response(code, request)
    end

    -- example of input parameters for check-script
    --   api:input
    --   {
    --     input:TEXT "requestDatetime";
    --     input:TEXT "action";
    --     input:TEXT "md5";
    --     input:TEXT "shopId";
    --     input:OPTIONAL_TEXT "shopArticleId";
    --     input:TEXT "invoiceId";
    --     input:OPTIONAL_TEXT "orderNumber";
    --     input:TEXT "customerNumber";
    --     input:TEXT "orderCreatedDatetime";
    --     input:TEXT "orderSumAmount";
    --     input:TEXT "orderSumCurrencyPaycash";
    --     input:TEXT "orderSumBankPaycash";
    --     input:TEXT "shopSumAmount";
    --     input:TEXT "shopSumCurrencyPaycash";
    --     input:TEXT "shopSumBankPaycash";
    --     input:TEXT "paymentPayerCode";
    --     input:NUMBER "orderIsPaid";
    --     input:OPTIONAL_TEXT "paymentDatetime";
    --     input:NUMBER "paymentType";
    --   };
    local yandex_check = function(api_context, application, request)
      arguments(
          "table", api_context,
          "table", application,
          "table", request
        )

      api_context:ext("history.cache"):try_append(
          api_context,
          request.customerNumber,
          " Check request: " .. tstr(request)
        )

      if request.action ~= "Check" then
        return fail(
            "INCORRECT_INPUT",
            "[ya/check] incorrect action: " .. (request.action or "NIL")
          )
      end

      if request.orderIsPaid ~= 0 then
        return fail(
            "INCORRECT_INPUT",
            "[ya/check] incorrect value of orderIsPaid"
          )
      end

      if ya_create_hash(request, application) ~= request.md5 then
        return fail("INCORRECT_HASH", "[ya/check] incorrect hash of request")
      end

      local transaction_id = "transaction:" .. request.customerNumber
      local payment = api_context:ext("transactions.cache"):try_get(
          api_context,
          transaction_id
        )
      if next(payment) == nil then
        --TODO: need to search payment in request queue
        return fail(
            "INTERNAL_ERROR",
            "[ya/check] transaction not found: " .. transaction_id
          )
      end
      payment.transaction_id = transaction_id

      local src_t = tclone(payment)

      request.orderSumAmount = tonumber(request.orderSumAmount)
      request.shopSumAmount = tonumber(request.shopSumAmount)
      if
        request.orderSumAmount <= 0
        or request.shopSumAmount <= 0
        or request.shopSumAmount > request.orderSumAmount
      then
        return fail("DATA_NOT_MATCH", "[ya/check] incorrect amounts in request")
      end

      payment.amount = tonumber(payment.amount)
      local orderSumAmount = request.orderSumAmount * 100
      if not pkb_price_equals(orderSumAmount, payment.amount) then
        pkb_check_price(
            api_context,
            transaction_id,
            orderSumAmount,
            payment.amount
          )
        payment.amount = orderSumAmount
      end

      payment.status = tonumber(payment.status)
        or PKB_TRANSACTION_STATUS.INVALID
      if payment.status ~= PKB_TRANSACTION_STATUS.CONFIRMED_BY_APP then
        local code = "DATA_NOT_MATCH"
        if payment.status == PKB_TRANSACTION_STATUS.WAITING_CONFIRMATION_BY_APP then
          code = "WAIT_FOR_RESULT"
        end
        return fail(code, "[ya/check] incorrect status of transaction")
      end

      --TODO: save payment in redis
      api_context:ext("history.cache"):try_append(
          api_context,
          request.customerNumber,
          " Check request: result code: 0"
        )
      log(
          "[ya/check] check request accepted successfully for transaction : ",
          transaction_id
        )

      --save invoiceId
      payment.payment_id = request.invoiceId
      api_context:ext("transactions.cache"):try_set(api_context, payment, src_t)

      return ya_build_response("OK", request)
    end

    -- example of input parameters for payment-script
    --   api:input
    --   {
    --     input:TEXT "requestDatetime";
    --     input:TEXT "action";
    --     input:TEXT "md5";
    --     input:TEXT "shopId";
    --     input:OPTIONAL_TEXT "shopArticleId";
    --     input:TEXT "invoiceId";
    --     input:OPTIONAL_TEXT "orderNumber";
    --     input:TEXT "customerNumber";
    --     input:TEXT "orderCreatedDatetime";
    --     input:TEXT "orderSumAmount";
    --     input:TEXT "orderSumCurrencyPaycash";
    --     input:TEXT "orderSumBankPaycash";
    --     input:TEXT "shopSumAmount";
    --     input:TEXT "shopSumCurrencyPaycash";
    --     input:TEXT "shopSumBankPaycash";
    --     input:TEXT "paymentPayerCode";
    --     input:NUMBER "orderIsPaid";
    --     input:TEXT "paymentDateTime";
    --     input:NUMBER "paymentType";
    --   };
    local yandex_payment = function(api_context, application, request)
      arguments(
          "table", api_context,
          "table", application,
          "table", request
        )

      api_context:ext("history.cache"):try_append(
          api_context,
          request.customerNumber,
          " Payment request: " .. tstr(request)
        )

      if request.action ~= "PaymentSuccess" then
        return fail(
            "INCORRECT_INPUT",
            "[ya/paymentaviso] incorrect action: " .. (request.action or "NIL")
          )
      end

      if not request.orderIsPaid then
        return fail(
            "INCORRECT_INPUT",
            "[ya/paymentaviso] incorrect value of orderIsPaid"
          )
      end

      if ya_create_hash(request, application) ~= request.md5 then
        return fail("INCORRECT_HASH",  "[ya/paymentaviso] incorrect md5 hash")
      end

      local transaction_id = "transaction:" .. request.customerNumber
      local payment = api_context:ext("transactions.cache"):try_get(
          api_context,
          transaction_id
        )
      if next(payment) == nil then
        return fail(
            "INTERNAL_ERROR",
            "[ya/paymentaviso] transaction #"
              .. request.customerNumber
              .. " not found"
          )
      end
      local src_t = tclone(payment)

      request.orderSumAmount = tonumber(request.orderSumAmount)
      request.shopSumAmount = tonumber(request.shopSumAmount)
      if
        request.orderSumAmount <= 0
        or request.shopSumAmount <= 0
        or request.shopSumAmount > request.orderSumAmount
      then
        return fail(
            "DATA_NOT_MATCH",
            "[ya/paymentaviso] incorrect received amounts"
          )
      end

      payment.amount = tonumber(payment.amount)
      local orderSumAmount = request.orderSumAmount * 100
      if not pkb_price_equals(orderSumAmount, payment.amount) then
        pkb_check_price(
            api_context,
            transaction_id,
            orderSumAmount,
            payment.amount
          )
        payment.amount = orderSumAmount
      end

      payment.status = tonumber(payment.status)
        or PKB_TRANSACTION_STATUS.INVALID
      if
        payment.status ~= PKB_TRANSACTION_STATUS.CONFIRMED_BY_APP
        and payment.status ~= PKB_TRANSACTION_STATUS.CONFIRMED_BY_PAYSYSTEM
        and payment.status ~= PKB_TRANSACTION_STATUS.CLOSED_BY_APP
      then
        local code = "WAIT_FOR_RESULT"
        if
          payment.status == PKB_TRANSACTION_STATUS.INVALID
          or payment.status == PKB_TRANSACTION_STATUS.REJECTED_BY_APP
        then
          code = "INCORRECT_STATUS"
        end
        return fail(
            code,
            "[ya/paymentaviso] incorrect status of payment: " .. payment.status
          )
      end

      if payment.payment_id ~= request.invoiceId then
        return fail(
            "DATA_NOT_MATCH",
            "[ya/paymentaviso] Saved invoiceID not equals with received invoiceId"
          )
      end
      if
        payment.status == PKB_TRANSACTION_STATUS.CONFIRMED_BY_PAYSYSTEM
        or payment.status == PKB_TRANSACTION_STATUS.CLOSED_BY_APP
      then
        api_context:ext("history.cache"):try_append(
            api_context,
            request.customerNumber,
            " Payment duplicate request: result code: 0"
          )
        log("[ya/paymentaviso] duplicate request successfull accepted", request)
        return ya_build_response("OK", request)
      end

      payment.payment_id = request.invoiceId
      payment.status = PKB_TRANSACTION_STATUS.CONFIRMED_BY_PAYSYSTEM
      payment.pay_stime = os.time()
      payment.transaction_id = request.customerNumber

      log(
          "[ya/paymentaviso] payment request accepted successfully for transaction:",
          transaction_id
        )
      api_context:ext("history.cache"):try_append(
          api_context,
          request.customerNumber,
          " Payment request: result code: 0"
        )
      api_context:ext("transactions.cache"):try_set(api_context, payment, src_t)
      return ya_build_response("OK", request)
    end

  end;
}
