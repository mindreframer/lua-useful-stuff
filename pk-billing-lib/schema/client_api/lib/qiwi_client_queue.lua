--------------------------------------------------------------------------------
-- qiwi_client_queue.lua
-- This file is a part of pk-billing-lib library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------

api:export "lib/qwc_queue"
{
  exports =
  {
    -- data
    "QWC_REQUEST_QUEUE_KEY";
  };

  handler = function()
    local QWC_REQUEST_QUEUE_KEY = "spp:qiwi_client:queue"
  end
}

api:extend_context "qiwi_client.queue" (function()
  local try_pop = function(self, api_context, timeout)
    method_arguments(
        self,
        "table", api_context,
        "number", timeout
      )

    local cache = api_context:hiredis():transaction()

    -- get random request key from queue
    local data = try_unwrap(
        "INTERNA_ERROR",
         cache:command("BLPOP", QWC_REQUEST_QUEUE_KEY, timeout)
      )

    if data == hiredis.NIL then
      return nil, "Qiwi-client queue are empty"
    end

    if is_table(data) then
      local value = data[2]
      local transaction = api_context:ext("transactions.cache"):try_get(api_context, value)
      transaction.transaction_id = value

      return value, transaction
    end

    log("[qiwi_client.queue:try_pop] wrong redis response: ", data)
    return nil, "wrong redis response"
  end

  local try_get_length = function(self, api_context)
    method_arguments(
        self,
        "table", api_context
      )

    local cache = api_context:hiredis():transaction()

    return try_unwrap(
        "INTERNA_ERROR",
        cache:command("SCARD", QWC_REQUEST_QUEUE_KEY)
      )
  end

  local factory = function()
    return
    {
      try_pop = try_pop;
      length = try_get_length;
    }
  end

  -- TODO: its not work in standalone-services becuase they dont support zmq.
  -- https://redmine.iphonestudio.ru/issues/1472
  local system_action_handlers =
  {
    ["qiwi_client.queue:push"] = function(api_context, transaction_id)
      spam("qiwi_client.queue:push")

      -- TODO: LAZY HACK. This currently updates redis data
      --       once for each fork. It should do it once per save!
      local id = api_context:ext("qiwi_client.queue"):try_push(api_context, transaction_id)

      spam("/qiwi_client.queue:push")

      return id
    end;
  }

  return
  {
    factory = factory;
    system_action_handlers = system_action_handlers;
  }
end)
