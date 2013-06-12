--------------------------------------------------------------------------------
-- osmp.lua
-- This file is a part of pk-billing-lib library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------

api:export "lib/paysystems/osmp"
{
  exports =
  {
    "osmp_response_handler";
    "osmp_error_handler";

    "osmp_common";
    "osmp_check";
    "osmp_payment";
  };

  handler = function()
    local osmp_response_handler = function(body)
      return xml_response(body)
    end

    local osmp_error_handler = function(code, api_context)
      local request = api_context:get_request()

      code = OSMP_ERROR_CODES[code] or code
      return osmp_create_response(code, request)
    end

    -- example of input parameters for script
    --   api:input
    --   {
    --     use_GET = true;
    --     input:APPLICATION_ID "appid";
    --     input:TEXT "command";
    --     input:TEXT "txn_id";
    --     input:TEXT "sum"; --because OSMP send money as a string
    --     input:OPTIONAL_TEXT "txn_date";
    --     input:TEXT "account";
    --   };
    local osmp_common = function(api_context, application, request)
      arguments(
          "table", api_context,
          "table", application,
          "table", request
        )

      -- search trasnaction by txn_id
      local transaction, t_exist = osmp_search_transaction(
          api_context,
          application.id,
          request.txn_id
        )
      if transaction and transaction.transaction_id then
        api_context:ext("history.cache"):try_append(
            api_context,
            transaction.transaction_id,
            "Payment request: " .. tstr(request)
          )
      end

      local qiwi_amount = tonumber(request.sum) * 100
      if not qiwi_amount or qiwi_amount <= 0 then
        return fail(
            "BAD_INPUT",
            "[qiwi/payment] incorrect received amount: "
              .. tostring(qiwi_amount)
              .. ", "
              .. tostring(request.sum)
          )
      end

      request.transaction_id = request.txn_id
      if transaction then
        transaction.amount = tonumber(transaction.amount)
        if
          transaction.appid ~= application.id or
          transaction.paysystem_id ~= OSMP_PAYSYSTEM_ID or
          transaction.uid ~= request.account or
          transaction.payment_id ~= request.txn_id or
          not pkb_price_equals(qiwi_amount, transaction.amount)
        then
          log("[qiwi/payment] load application: ", application)
          local res = "appid = "
            .. tostring(transaction.appid ~= application.id)
            .. ", paysystem_id = "
            .. tostring(transaction.paysystem_id ~= OSMP_PAYSYSTEM_ID)
            .. ", account_id = "
            .. tostring(transaction.uid ~= request.account)
            .. ", txn_id = "
            .. tostring(transaction.payment_id ~= request.txn_id)
            .. ", amount = "
            .. tostring(not pkb_price_equals(qiwi_amount, transaction.amount))

          log_error(
              "[qiwi/payment] saved and received data for transaction "
                .. transaction.transaction_id
                .. " does not match: ",
              res
            )
          api_context:ext("history.cache"):try_append(
              api_context,
              transaction.transaction_id,
              "Saved and received data does not match"
            )
          return fail(
              "BAD_INPUT",
              "[qiwi/payment] saved and received data for transaction does not match"
            )
        end
        transaction.status = tonumber(transaction.status)
      end

      return transaction, t_exist
    end

    local osmp_check = function(
        api_context,
        application,
        request,
        transaction,
        transaction_exist
      )
      arguments(
          "table", api_context,
          "table", application,
          "table", request
          -- "table", transaction,
          -- "boolean", transaction_exist
        )

      local qiwi_amount = tonumber(request.sum) * 100

      if request.account ~= request.account:match("%d+") then
        log_error("[osmp/check] incorrect format of account: ", request.account)
        return osmp_build_response("INCORRECT_ACCOUNT_FORMAT", request)
      end

      if not transaction and not transaction_exist then
        --TODO: save in request_handler queue
        local pkb_request =
        {
          appid = application.id;
          uid = request.account;
          paysystem_id = OSMP_PAYSYSTEM_ID;
          paysystem_subid = 0;
          amount = qiwi_amount;
          stime = os.time();
          payment_id = request.txn_id;
          status = PKB_TRANSACTION_STATUS.WAITING_CONFIRMATION_BY_APP;
        }
        pkb_request.transaction_id = api_context:ext(
            "request_queue.cache"
          ):try_set(
              api_context,
              pkb_request
            )
        api_context:ext("history.cache"):try_append(
            api_context,
            pkb_request.transaction_id,
            "[osmp/check] Add request in queue, txn_id: " .. request.txn_id
          )
        log(
            "[osmp/check] add request in queue, txn_id: ",
            request.txn_id,
            " t_id: ",
            pkb_request.transaction_id
          )

        local res, err = osmp_save_transaction(
            api_context,
            application.id,
            pkb_request
          )
        if not res then
          log_error("[osmp/check] qiwi_save_transaction error: ", err)
          api_context:ext("history.cache"):try_append(
              api_context,
              pkb_request.transaction_id,
              "[osmp/check] qiwi_save_transaction error: " .. err
            )
          return osmp_build_response("INTERNAL_ERROR", request)
        end

        -- HACK: we block worker while wait results of check
        -- TODO: its must be a async request to application
        -- https://redmine.iphonestudio.ru/issues/1238
        local result = osmp_blpop_request(
            api_context,
            pkb_request.transaction_id
          )
        if not result then
          request.comment = "request still not checked"
          api_context:ext("history.cache"):try_append(
              api_context,
              pkb_request.transaction_id,
              "[osmp/check] result: WAIT_RESULT"
            )
          return osmp_build_response("WAIT_RESULT", request)
        elseif
          is_table(result)
          and tonumber(result.status) == PKB_TRANSACTION_STATUS.CONFIRMED_BY_APP
        then
          api_context:ext("history.cache"):try_append(
              api_context,
              pkb_request.transaction_id,
              "[osmp/check] result: OK"
            )
          return osmp_build_response("OK", request)
        elseif
          is_table(result)
          and tonumber(result.status) == PKB_TRANSACTION_STATUS.REJECTED_BY_APP
        then
          log_error("[osmp/check] Account not found: ", request)
          api_context:ext("history.cache"):try_append(
              api_context,
              pkb_request.transaction_id,
              "[osmp/check] result: ACCOUNT NOT FOUND"
            )
          return osmp_build_response("ACCOUNT_NOT_FOUND", request)
        end
        -- /HACK

        return osmp_build_response("FATAL_ERROR", request)
      elseif not transaction and transaction_exist then
        log(
            "[osmp/check] request still not checked, txn_id: "
              .. request.txn_id
          )
        request.comment = "request still not checked"
        return osmp_build_response("WAIT_RESULT", request)
      elseif transaction then
        osmp_rm_request(api_context, transaction.transaction_id)
        if not OSMP_ALLOWED_PAYMENT_STATUS[transaction.status] then
          log_error(
              "[osmp/check] incorrect status of transaction: ",
              transaction.transaction_id,
              ", status ",
              transaction.status
            )
          api_context:ext("history.cache"):try_append(
              api_context,
              transaction.transaction_id,
              "[osmp/check] Incorrect status of transaction: "
                .. tonumber(transaction.status)
            )
          return osmp_build_response("FAIL", request)
        end
        if transaction.status == PKB_TRANSACTION_STATUS.REJECTED_BY_APP then
          log_error(
              "[osmp/check] account: ",
              request.account,
              " not found in application: ",
              application.id
            )
          api_context:ext("history.cache"):try_append(
              api_context,
              transaction.transaction_id,
              "[osmp/check] account not found"
            )
          return osmp_build_response("ACCOUNT_NOT_FOUND", request)
        end

        log("[osmp/check]: check request confirmed: ", request)
        api_context:ext("history.cache"):try_append(
            api_context,
            transaction.transaction_id,
            "[osmp/check] request confirmed"
          )
        return osmp_build_response("OK", request)
      end
      return osmp_build_response("INTERNAL_ERROR", request)
    end

    local osmp_payment = function(api_context, application, request, transaction)
      arguments(
          "table", api_context,
          "table", application,
          "table", request,
          "table", transaction
        )

      if not transaction then
        return fail(
            "TRANSACTION_NOT_FOUND",
            "[osmp/pay]: Transaction for txn_id: "
              .. request.txn_id
              .. "not found"
          )
      end

      local src_t = tclone(transaction)

      if OSMP_CLOSED_PAYMENTS[transaction.status] then
        log(
            "[osmp/pay] duplicate request (code = 0) for t_id: ",
            transaction.transaction_id,
            ", txn_id: ",
            request.txn_id
          )
        api_context:ext("history.cache"):try_append(
            api_context,
            transaction.transaction_id,
            "[osmp/pay] duplicate request (code = 0) "
          )
        return osmp_build_response("OK", request)
      end
      if transaction.status ~= PKB_TRANSACTION_STATUS.CONFIRMED_BY_APP then
        log_error(
            "[osmp/pay] incorrect status ",
            transaction.status,
            " of t_id: ",
            transaction.transaction_id
          )
        api_context:ext("history.cache"):try_append(
            api_context,
            transaction.transaction_id,
            "[osmp/pay] incorrect status " .. tostring(transaction.status)
          )
        return osmp_build_response("FAIL", request)
      end

      transaction.status = PKB_TRANSACTION_STATUS.CONFIRMED_BY_PAYSYSTEM
      transaction.pay_stime = os.time()

      api_context:ext("transactions.cache"):try_set(
          api_context,
          transaction,
          src_t
        )
      log(
          "[osmp/pay] pay request confirmed: ",
          request,
          transaction.transaction_id
        )
      api_context:ext("history.cache"):try_append(
          api_context,
          transaction.transaction_id,
          "[osmp/pay] pay request confored"
        )
      return osmp_build_response("OK", request)
    end
  end;
}
