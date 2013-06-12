--------------------------------------------------------------------------------
-- webmoney.lua
-- This file is a part of pk-billing-lib library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------

api:export "lib/paysystems/webmoney"
{
  exports =
  {
    "webmoney_response_handler";
    "webmoney_error_handler";

    "webmoney_request";
  };

  handler = function()
    local webmoney_response_handler = function(body)
      return html_response(body)
    end

    local webmoney_error_handler = function(code, api_context)
      local request = api_context:post_request()

      if request.transaction_id ~= nil then
        api_context:ext("history.cache"):try_append(
            api_context,
            request.transaction_id,
            "wm/payment request: result code: " .. tostring(code)
          )
      end

      code = WM_ERROR_CODES[code] or code
      return code
    end

    -- example of input parameters for script
    --   api:input
    --   {
    --     -- CHECK REQUEST
    --     input:OPTIONAL_NUMBER "LMI_PREREQUEST";
    --
    --     -- PAYMENT REQUEST
    --     input:OPTIONAL_NUMBER "LMI_SYS_INVS_NO";
    --     input:OPTIONAL_NUMBER "LMI_SYS_TRANS_NO";
    --     input:OPTIONAL_TEXT "LMI_HASH";
    --     input:OPTIONAL_TEXT "LMI_SYS_TRANS_DATE";
    --
    --     -- COMMON FIELDS
    --     input:TEXT "LMI_PAYEE_PURSE";
    --     input:TEXT "LMI_PAYMENT_AMOUNT";
    --     input:TEXT "LMI_PAYMENT_NO";
    --     input:PAYMENT_ID "transaction_id";
    --     input:NUMBER "LMI_MODE";
    --     input:TEXT "LMI_PAYER_PURSE";
    --     input:TEXT "LMI_PAYER_WM";
    --   };
    local webmoney_request = function(api_context, application, request)
      arguments(
          "table", api_context,
          "table", application,
          "table", request
        )

      local history = { }

      local transaction = api_context:ext("transactions.cache"):try_get(
          api_context,
          request.transaction_id
        )
      if not next(transaction) then
        return fail(
            "INTERNAL_ERROR",
            "Transaction #" .. request.transaction_id .. " not found"
          )
      end
      local src_t = tclone(transaction)
      transaction.status = tonumber(transaction.status)

      local subtransaction = api_context:ext("subtransactions.cache"):try_get(
          api_context,
          request.transaction_id
        )

      local transaction_amount = tonumber(
          subtransaction.amount or transaction.amount
        )
      local wm_amount = tonumber(request.LMI_PAYMENT_AMOUNT) * 100

      if not pkb_price_equals(wm_amount, transaction_amount) then
        history[#history + 1] = "[wm] Saved ("
          .. transaction_amount
          .. ") and received ("
          .. wm_amount
          .. ") amount not equals"
        log_error(
            "[wm][",
            request.transaction_id,
            "] Saved (",
            transaction_amount,
            ") and received (",
            wm_amount,
            ") amount not equals"
          )
        -- save in cheaters
        pkb_check_price(
            api_context,
            request.transaction_id,
            wm_amount,
            transaction_amount
          )
        local rate = pkb_get_rate(
            application,
            WM_PAYSYSTEM_ID,
            transaction.paysystem_subid
          )
        transaction.amount = math.floor(wm_amount * rate)
        subtransaction.amount = wm_amount
      end

      local wm_wallets = tgetpath(application, "config", "wm_wallets") or { }
      wm_wallets = tflip(wm_wallets)
      local wallet = request.LMI_PAYEE_PURSE:upper()
      if not wm_wallets[wallet] then
        history[#history + 1] = "[wm] Unknown wallet: " .. wallet
        log_error("[wm][", request.transaction_id ,"] Unknown wallet: " .. wallet)
        return wm_build_response(
            api_context,
            "UNKNOWN_WALLET",
            request,
            history
          )
      end

      local wm_mode = tgetpath(application, "config", "wm_mode")
      wm_mode = WM_MODES[wm_mode] or WM_MODES[WM_DEFAULT_MODE]
      if wm_mode ~= request.LMI_MODE then
        -- TODO: PANIC?!
        history[#history + 1] = "[wm] WM mode in application ("
          .. wm_mode
          .. ") and received from WM ("
          .. request.LMI_MODE
          .. ") not equals"
        log_error(
            "[wm][",
            request.transaction_id,
            "] WM mode in application (",
            wm_mode,
            ") and received from WM (",
            request.LMI_MODE,
            ") not equals"
          )
        return wm_build_response(
            api_context,
            "INCORRECT_MODE",
            request,
            history
          )
      end

      if request.LMI_PREREQUEST and request.LMI_PREREQUEST == 1 then
        -- handle check request

        if transaction.status ~= PKB_TRANSACTION_STATUS.CONFIRMED_BY_APP then
          history[#history + 1] = "[wm/check] incorrect status of transaction: "
            .. transaction.status
          log_error(
              "[wm/check][",
              request.transaction_id ,
              "] incorrect status of transaction: ",
              transaction.status
            )
          return wm_build_response(
              api_context,
              "INCORRECT_STATUS",
              request,
              history
            )
        end

        history[#history + 1] = "[wm/check] Check request accepted successfully"
        log(
            "[wm/check][",
            request.transaction_id,
            "] Check request accepted successfully"
          )
        return wm_build_response(api_context, "OK", request, history)
      else
        -- handle payment request
        local res, err = wm_check_fields("payment", request)
        if not res then
          history[#history + 1] = "[wm/payment] error: " .. err
          log_error("[wm/payment][", request.transaction_id ,"] error: " .. err)
          return wm_build_response(api_context, "BAD_INPUT", request, history)
        end

        request.LMI_SECRET_KEY = tgetpath(
            application,
            "config",
            "wm_secret_key"
          )
        local hash, err = wm_create_hash(request)
        if not hash then
          history[#history + 1] = "[wm/payment] failed to create hash: " .. err
          log_error(
              "[wm/payment][",
              request.transaction_id,
              "] failed to create hash: ",
              err
            )
          return wm_build_response(api_context, "BAD_INPUT", request, history)
        end
        if hash ~= request.LMI_HASH then
          history[#history + 1] = "[wm/payment] incorrect hash. Received: "
            .. request.LMI_HASH
            .. ", required: "
            .. hash
          log_error(
              "[wm/payment][",
              request.transaction_id,
              "] incorrect hash. Received: ",
              request.LMI_HASH,
              ", required: ",
              hash
            )
          return wm_build_response(
              api_context,
              "INCORRECT_HASH",
              request,
              history
            )
        end

        if not WM_ALLOWED_PAYMENT_STATUSES[transaction.status] then
          history[#history + 1] = "[wm] incorrect status of transaction: "
            .. transaction.status
          log_error(
              "[wm][",
              request.transaction_id,
              "] incorrect status of transaction: ",
              transaction.status
            )
          return wm_build_response(
              api_context,
              "INCORRECT_STATUS",
              request,
              history
            )
        end

        if WM_CLOSED_PAYMENTS[transaction.status] then
          -- duplicate request
          history[#history + 1] = "[wm/payment] duplicate request"
          log("[wm/payment][", request.transaction_id ,"] duplicate request")
          return wm_build_response(
              api_context,
              "DUPLICATE_REQUEST",
              request,
              history
            )
        end

        transaction.status = PKB_TRANSACTION_STATUS.CONFIRMED_BY_PAYSYSTEM
        transaction.payment_id = request.LMI_SYS_TRANS_NO
        transaction.pay_stime = os.time()
        transaction.transaction_id = request.transaction_id

        history[#history + 1] = "[wm/payment] payment request accepted successfully"
        log(
            "[wm/payment][",
            request.transaction_id,
            "] payment request accepted successfully"
          )
        api_context:ext("subtransactions.cache"):try_set(
            api_context,
            request.transaction_id,
            subtransaction
          )
        api_context:ext("transactions.cache"):try_set(
            api_context,
            transaction,
            src_t
          )
        api_context:ext("webmoney.cache"):try_set(api_context, request)
        return wm_build_response(api_context, "OK", request, history)
      end
    end
  end;
}
