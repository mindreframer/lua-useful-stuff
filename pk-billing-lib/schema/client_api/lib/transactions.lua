--------------------------------------------------------------------------------
-- transactions.lua
-- This file is a part of pk-billing-lib library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------

api:extend_context "transactions.cache" (function()
  local try_get = function(self, api_context, transaction_id, field)
    method_arguments(
        self,
        "table", api_context,
        "string", transaction_id
      )

    local cache = api_context:hiredis():transaction()
    transaction_id = pkb_normalize_transaction_id(transaction_id)

    local result = { }
    if field ~= nil then
      result = try_unwrap(
          "INTERNAL_ERROR",
          cache:command("HGET", transaction_id, field)
        )
    else
      result = try_unwrap(
          "INTERNAL_ERROR",
          cache:command("HGETALL", transaction_id)
        )
      result = tkvlist2kvpairs(result)
    end
    return result
  end

  local try_set = function(self, api_context, transaction, src_transaction)
    method_arguments(
        self,
        "table", api_context,
        "table", transaction
      )

    local transaction_id = pkb_normalize_transaction_id(tostring(transaction.transaction_id))

    local transaction_ = { }
    for i = 1, #PKB_TRANSACTION_FIELDS do
      local key = PKB_TRANSACTION_FIELDS[i]
      if transaction[key] then
        transaction_[key] = transaction[key]
      end
    end

    transaction = transaction_

    --start: calc counters
    local old_status = nil
    if src_transaction then
      arguments("table", src_transaction)
      old_status = src_transaction.status
    end
    if old_status ~= transaction.status or not old_status then
      stats_calc_counter(
          api_context,
          transaction.appid,
          transaction.paysystem_id,
          tonumber(transaction.status),
          tonumber(old_status)
        )
    end
    --end: calc counters

    local old_time = transaction.stime or 0
    if
      transaction.paysystem_id ~= TEST_PAYSYSTEM_ID or
      not transaction.stime
    then
      transaction.stime = os.time()
    end

    local time = pkb_get_time_hash(transaction.stime)
    local old_time_hash = pkb_get_time_hash(tonumber(old_time))

    local cache = api_context:hiredis():transaction()

    local need_add = true
    if old_time ~= 0 and old_time_hash ~= time then
      local from_key = "application:" .. transaction.appid .. ":" .. old_time_hash .. ":transactions"
      local to_key = "application:" .. transaction.appid .. ":" .. time .. ":transactions"
      local move_res = try_unwrap(
          "INTERNAL_ERROR",
          cache:command("SMOVE", from_key, to_key, transaction_id)
        )
      need_add = move_res ~= 1
    end

    -- add try_unwrap("INTERNAL_ERROR", cache:get_reply()) for each request added to
    -- MULTI
    -- TODO: find more evident way to handle this
    cache:append_command("MULTI")
    try_unwrap(
        "INTERNAL_ERROR",
        cache:append_command("SADD", "application:" .. transaction.appid .. ":dates", time)
      )
    if need_add then
      try_unwrap(
          "INTERNAL_ERROR",
          cache:append_command(
              "SADD",
              "application:" .. transaction.appid .. ":" .. time .. ":transactions",
              transaction_id
            )
        )
    end
    for key, value in pairs(transaction) do
      try_unwrap(
          "INTERNAL_ERROR",
          cache:append_command("HMSET", transaction_id, key, value)
        )
    end

    if transaction.paysystem_id == QIWI_PAYSYSTEM_ID then
      if transaction.status == PKB_TRANSACTION_STATUS.CONFIRMED_BY_APP then
        log("add transaction ", transaction_id, " into qiwi monitored list")
        try_unwrap(
            "INTERNAL_ERROR",
            cache:append_command("LPUSH", PKB_QIWIM_QUEUE, transaction_id)
          )
      elseif transaction.status == PKB_TRANSACTION_STATUS.WAITING_FOR_PAYSYSTEM_BILL_CREATION then
        log("add transaction ", transaction_id, " into qiwi_client queue")
        try_unwrap(
            "INTERNAL_ERROR",
            cache:append_command("LPUSH", QWC_REQUEST_QUEUE_KEY, transaction_id)
          )
      end
    end
    if
      transaction.status == PKB_TRANSACTION_STATUS.CONFIRMED_BY_APP
      and transaction.paysystem_id == VK_PAYSYSTEM_ID
    then
      log("add transaction ", transaction_id, " into vk monitored list")
      try_unwrap(
          "INTERNAL_ERROR",
          cache:append_command("LPUSH", PKB_VKMON_QUEUE, transaction_id)
        )
    end
    if
      (
        transaction.status == PKB_TRANSACTION_STATUS.CONFIRMED_BY_APP or
        transaction.status == PKB_TRANSACTION_STATUS.REJECTED_BY_APP
      ) and
      transaction.paysystem_id == OSMP_PAYSYSTEM_ID
    then
      local pkkey = pkb_parse_pkkey(transaction_id)
      local key = OSMP_REQUEST_KEY .. pkkey
      log("create key: ", key, transaction_id)
      try_unwrap(
          "INTERNAL_ERROR",
          cache:append_command("RPUSH", key, transaction_id)
        )
    end
    if
      transaction.status == PKB_TRANSACTION_STATUS.CONFIRMED_BY_PAYSYSTEM
      and transaction.paysystem_id ~= TEST_PAYSYSTEM_ID
    then
      try_unwrap(
          "INTERNAL_ERROR",
          cache:append_command("RPUSH", PKB_APPNOTIFICATOR_QUEUE, transaction_id)
        )
    end
    cache:append_command("EXEC")

    -- this block handles replies from MULTI request above
    try_unwrap("INTERNAL_ERROR", cache:get_reply()) -- multi
    try_unwrap("INTERNAL_ERROR", cache:get_reply()) -- sadd
    if need_add then
      try_unwrap("INTERNAL_ERROR", cache:get_reply()) -- sadd
    end
    for key, value in pairs(transaction) do
      try_unwrap("INTERNAL_ERROR", cache:get_reply()) -- hmset
    end
    if
      transaction.status == PKB_TRANSACTION_STATUS.CONFIRMED_BY_PAYSYSTEM
      and transaction.paysystem_id ~= TEST_PAYSYSTEM_ID
    then
      try_unwrap("INTERNAL_ERROR", cache:get_reply()) -- rpush
    end
    if
      transaction.status == PKB_TRANSACTION_STATUS.CONFIRMED_BY_APP and
      transaction.paysystem_id == VK_PAYSYSTEM_ID
    then
      try_unwrap("INTERNAL_ERROR", cache:get_reply()) -- lpush
    end
    if transaction.paysystem_id == QIWI_PAYSYSTEM_ID then
      if
        transaction.status == PKB_TRANSACTION_STATUS.CONFIRMED_BY_APP or
        transaction.status == PKB_TRANSACTION_STATUS.WAITING_FOR_PAYSYSTEM_BILL_CREATION
      then
        try_unwrap("INTERNAL_ERROR", cache:get_reply()) -- lpush
      end
    end
    if
      (
        transaction.status == PKB_TRANSACTION_STATUS.CONFIRMED_BY_APP or
        transaction.status == PKB_TRANSACTION_STATUS.REJECTED_BY_APP
      ) and
      transaction.paysystem_id == OSMP_PAYSYSTEM_ID
    then
      try_unwrap("INTERNAL_ERROR", cache:get_reply()) -- rpush
    end
    try_unwrap("INTERNAL_ERROR", cache:get_reply()) -- exec
  end

  local try_get_done_payments = function(self, api_context, appid)
    method_arguments(
        self,
        "table", api_context,
        "string", appid
      )
    local cache = api_context:hiredis():transaction()

    local key = PKB_TRANSACTIONS_DONE_KEY .. appid
    local payment_ids = try_unwrap(
        "INTERNAL_ERROR",
        cache:command("SMEMBERS", key)
      )
    return payment_ids
  end

  local factory = function()

    return
    {
      try_get = try_get;
      try_set = try_set;

      try_get_done_payments = try_get_done_payments;
    }
  end

  -- TODO: its not work in standalone-services becuase they dont support zmq.
  -- https://redmine.iphonestudio.ru/issues/1472
  local system_action_handlers =
  {
    ["transactions.cache:set"] = function(api_context, transaction)
      spam("transactions.cache:set")

      -- TODO: LAZY HACK. This currently updates redis data
      --       once for each fork. It should do it once per save!
      api_context:ext("transactions.cache"):try_set(api_context, transaction)

      spam("/transactions.cache")

      return true
    end;
  }

  return
  {
    factory = factory;
    system_action_handlers = system_action_handlers;
  }
end)

api:extend_context "transactions.queue" (function()
  local try_rm_monitored_transactions = function(
        self,
        api_context,
        queue_key,
        t_id
      )
    method_arguments(
        self,
        "table", api_context,
        "string", queue_key,
        "string", t_id
      )
    local cache = api_context:hiredis():transaction()

    t_id = pkb_normalize_transaction_id(t_id)
    local res = try_unwrap(
        "INTERNAL_ERROR",
        cache:command("LREM", queue_key, 0, t_id)
      )

    if tonumber(res) == 0 then
      -- trying to remove a transaction with short id only if can not remove
      -- the normalized id
      t_id = pkb_parse_pkkey(t_id)
      res = try_unwrap(
          "INTERNAL_ERROR",
          cache:command("LREM", queue_key, 0, t_id)
        )

      if tonumber(res) == 0 then
        log_error(
            "[try_rm_monitored_transactions] failed "
              .. "remove transaction from queue: ",
            t_id
          )
      end
    end

    self.transactions_cache_[t_id] = nil
    self.length_tc_ = self.length_tc_ - 1
  end

  -- private method
  local get_transaction_appid = function(
        self,
        api_context,
        transaction_id,
        queue_size
      )
    method_arguments(
          self,
          "table", api_context,
          "string", transaction_id,
          "number", queue_size
        )

    local result = self.transactions_cache_[transaction_id]
    if result == nil then
      result = api_context:ext("transactions.cache"):try_get(
          api_context,
          transaction_id,
          "appid"
        )

      if self.length_tc_ < queue_size then
        self.transactions_cache_[transaction_id] = result
        spam("add transaction into local cache", transaction_id)
        self.length_tc_ = self.length_tc_ + 1
      end
    end

    return result
  end

  local try_get_monitored_transactions = function(
        self,
        api_context,
        queue_key,
        queue_size,
        queue_part_size
      )
    method_arguments(
        self,
        "table", api_context,
        "string", queue_key,
        "number", queue_size,
        "number", queue_part_size
      )
    local cache = api_context:hiredis():transaction()
    local transactions = try_unwrap(
        "INTERNAL_ERROR",
        cache:command("LRANGE", queue_key, 0, queue_part_size - 1)
      )

    local t_list = { }
    for i = 1, #transactions do
      local tid = transactions[i]
      local appid = get_transaction_appid(self, api_context, tid, queue_size)
      if appid ~= hiredis.NIL then
        tsetpath(t_list, appid)
        t_list[appid][#t_list[appid] + 1] = tid
      else
        api_context:ext("transactions.cache"):try_rm_monitored_transactions(
            api_context,
            queue_key,
            tid
          )
      end
    end

    return t_list
  end

  local factory = function()
    return
    {
      try_rm_monitored_transactions = try_rm_monitored_transactions;
      try_get_monitored_transactions = try_get_monitored_transactions;

      -- WARNING: cache cleared only when services restarted
      --local cache
      -- for save applications
      transactions_cache_ = { };
      length_tc_ = 0;
      -- end of local cache
    }
  end

  local system_action_handlers =
  {
  }

  -- TODO: its not work in standalone-services becuase they dont support zmq.
  -- https://redmine.iphonestudio.ru/issues/1472
  return
  {
    factory = factory;
    system_action_handlers = system_action_handlers;
  }
end)
