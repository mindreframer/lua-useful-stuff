--------------------------------------------------------------------------------
-- frontend.lua
-- This file is a part of pk-billing-lib library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------

api:extend_context "frontend.cache" (function()
  local create_form = function(self, api_context, request, paysystem, application)
    method_arguments(
        self,
        "table", api_context,
        "table", request
      )

    -- amount always given in minimum units (pennies, cents or diamonds, stars)
    -- it is always an integer and decimal part can discard
    local project_price = math.floor(request.amount)
    local default_price, currency_price = project_price, project_price
    local allowed_amounts_type = tgetpath(application, "config", "allowed_amounts_type") or PKB_DEFAULT_ALLOWED_AMOUNT_TYPE
    if allowed_amounts_type == PKB_AMOUNTS_TYPE_FIXED then
      currency_price, default_price = pkb_get_amounts_from_set(application, project_price, paysystem.id, request.paysystem_subid)
      if not currency_price or not default_price then
        return nil, "INCORRECT_AMOUNT", "amount absent in amounts_set: " .. request.amount
      end
      request.amount = default_price
    end


    local amounts = pkb_get_amounts_range(application, paysystem.id, request.paysystem_subid)
    if amounts ~= nil then
      -- if application.config.amounts present-> check amount
      if
        currency_price < amounts.min or
        currency_price > amounts.max
      then
        return nil, "INCORRECT_AMOUNT", "incorrect amount in request: " .. currency_price
      end
    end

    if not request.request_id then
      --save request in queue
      request.status = PKB_TRANSACTION_STATUS.WAITING_CONFIRMATION_BY_APP
      request.id = api_context:ext("request_queue.cache"):try_set(api_context, request)
      if paysystem.id == VK_PAYSYSTEM_ID and currency_price ~= project_price then
        -- save subtransaction with amount in subpaysystem currency
        local subtransaction =
        {
          amount = currency_price;
        }
        api_context:ext("subtransactions.cache"):try_set(api_context, request.id, subtransaction)
      end
      return { request_id = request.id }
    end

    --get request
    local request_status = pkb_get_transaction_status(api_context, request.request_id)
    if request_status ~= PKB_TRANSACTION_STATUS.NOT_FOUND then
      -- if transaction found -> always save subtransaction
      if currency_price ~= project_price then
        -- save subtransaction with amount in subpaysystem currency
        local subtransaction =
        {
          amount = currency_price;
        }
        api_context:ext("subtransactions.cache"):try_set(api_context, request.request_id, subtransaction)
      end
    end

    if request_status == PKB_TRANSACTION_STATUS.REJECTED_BY_APP then
      -- send error: account not found
      return nil, "ACCOUNT_NOT_FOUND", "Request " .. request.request_id .. " rejected by application"
    elseif request_status == PKB_TRANSACTION_STATUS.WAITING_CONFIRMATION_BY_APP then
      return { request_id = request.request_id }
    elseif request_status == PKB_TRANSACTION_STATUS.WAITING_FOR_PAYSYSTEM_BILL_CREATION then
      return { request_id = request.request_id }
    elseif request_status == PKB_TRANSACTION_STATUS.PAYSYSTEM_FAILED_TO_CREATE_BILL then
      return nil, "FAILED_TO_CREATE_ACCOUNT", "failed to create bill for transaction: " .. request.request_id
    elseif request_status == PKB_TRANSACTION_STATUS.CONFIRMED_BY_APP then
      -- send form
      local form = tgetpath(application, "config", "paysystems", paysystem.id) or { }
      local subpaysystem_config = tgetpath(paysystem, "config", "subpaysystems", tostring(request.paysystem_subid)) or tgetpath(paysystem, "config", "subpaysystems", "default")
      form = tappend_many(form, paysystem.config.form, subpaysystem_config)

      --TODO: get ALL data from paysystem config
      local paysystem_amount = currency_price / 100
      if paysystem_amount < PKB_MIN_TRANSSACTION_AMOUNT then
        return nil, "INCORRECT_AMOUNT", "request amount is very small: " .. paysystem_amount
      end
      paysystem_amount = tostring(paysystem_amount)

      --Yandex
      if paysystem.id == YM_PAYSYSTEM_ID then
        form.customerNumber = request.request_id
        form.Sum = paysystem_amount

      --Qiwi
      elseif paysystem.id == QIWI_PAYSYSTEM_ID then
        form.txn_id = request.request_id
        form.summ = paysystem_amount

      --OD
      elseif paysystem.id == OD_PAYSYSTEM_ID then
        form.nickname = request.request_id
        form.amount = paysystem_amount

      --WM
      elseif paysystem.id == WM_PAYSYSTEM_ID then
        local wm_wallets = tgetpath(application, "config", "wm_wallets") or { }
        if not wm_wallets[request.wallet] then
          return nil, "PAYSYSTEM_NOT_FOUND", "Unknown webmoney wallet: " .. request.wallet
        end
        form.LMI_PAYEE_PURSE = wm_wallets[request.wallet]
        form.LMI_PAYMENT_AMOUNT = paysystem_amount
        form.transaction_id = request.request_id

      -- VK
      elseif paysystem.id == VK_PAYSYSTEM_ID then
        form.request_id = request.request_id
      end

      log(
          "INFO: created transaction: ", request.request_id,
          "uid:", request.uid,
          "project_price:", project_price,
          "currency_price:", currency_price,
          "paysystem:", paysystem.title,
          "subpaysystem:", request.paysystem_subid
        )
      return { form = form }
    else
      -- send error: internal error
      return nil, "INTERNAL_ERROR", "Request " .. request.request_id .. " has incorrect status for create paymnt form - " .. request_status
    end
  end

  local factory = function()
    return
    {
      create_form = create_form;
    }
  end

  -- TODO: its not work in standalone-services becuase they dont support zmq.
  -- https://redmine.iphonestudio.ru/issues/1472
  local system_action_handlers =
  {
    ["frontend.cache:create_form"] = function(api_context, request, paysystem)
      spam("frontend.cache:create_form")

      -- TODO: LAZY HACK. This currently updates redis data
      --       once for each fork. It should do it once per save!
      api_context:ext("frontend.cache"):create_form(api_context, request, paysystem)

      spam("/frontend.cache:create_form")

      return true
    end;
  }

  return
  {
    factory = factory;
    system_action_handlers = system_action_handlers;
  }
end)
