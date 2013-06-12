--------------------------------------------------------------------------------
-- subtransactions.lua
-- This file is a part of pk-billing-lib library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------

api:extend_context "subtransactions.cache" (function()
  local try_get = function(self, api_context, transaction_id, field)
    method_arguments(
        self,
        "table", api_context,
        "string", transaction_id
      )

    local cache = api_context:hiredis():subtransaction()
    transaction_id = PKB_COMMON_PREFIX .. pkb_normalize_transaction_id(transaction_id)

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

  local try_set = function(self, api_context, transaction_id, transaction)
    method_arguments(
        self,
        "table", api_context,
        "string", transaction_id,
        "table", transaction
      )

    local cache = api_context:hiredis():subtransaction()
    transaction_id = PKB_COMMON_PREFIX .. pkb_normalize_transaction_id(transaction_id)

    -- add try_unwrap("INTERNAL_ERROR", cache:get_reply()) for each request added to
    -- MULTI
    -- TODO: find more evident way to handle this
    cache:append_command("MULTI")
    for key, value in pairs(transaction) do
      try_unwrap(
          "INTERNAL_ERROR",
          cache:append_command("HMSET", transaction_id, key, value)
        )
    end
    cache:append_command("EXEC")

    -- this block handles replies from MULTI request above
    try_unwrap("INTERNAL_ERROR", cache:get_reply()) -- multi
    for key, value in pairs(transaction) do
      try_unwrap("INTERNAL_ERROR", cache:get_reply()) -- hmset
    end
    try_unwrap("INTERNAL_ERROR", cache:get_reply()) -- exec
  end

  local factory = function()

    return
    {
      try_get = try_get;
      try_set = try_set;
    }
  end

  -- TODO: its not work in standalone-services becuase they dont support zmq.
  -- https://redmine.iphonestudio.ru/issues/1472
  local system_action_handlers =
  {
    ["subtransactions.cache:set"] = function(api_context, transaction)
      spam("subtransactions.cache:set")

      -- TODO: LAZY HACK. This currently updates redis data
      --       once for each fork. It should do it once per save!
      api_context:ext("subtransactions.cache"):try_set(api_context, transaction)

      spam("/subtransactions.cache:set")

      return true
    end;
  }

  return
  {
    factory = factory;
    system_action_handlers = system_action_handlers;
  }
end)
