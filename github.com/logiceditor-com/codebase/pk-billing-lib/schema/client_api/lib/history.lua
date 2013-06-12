--------------------------------------------------------------------------------
-- history.lua
-- This file is a part of pk-billing-lib library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------

api:extend_context "history.cache" (function()
  local try_get = function(self, api_context, transaction_id)
    method_arguments(
        self,
        "table", api_context,
        "string", transaction_id
      )

    local cache = api_context:hiredis():history()
    transaction_id = pkb_normalize_transaction_id(transaction_id)

    return try_unwrap(
        "INTERNAL_ERROR",
        cache:command("GET", transaction_id)
      )
  end

  local try_append = function(self, api_context, transaction_id, ...)
    method_arguments(
        self,
        "table", api_context,
        "string", transaction_id
      )

    transaction_id = pkb_normalize_transaction_id(transaction_id)

    local nargs = select("#", ...)
    if nargs <=0 then
      return fail("BAD_ARGUMENTS", "arguments list are empty")
    end

    local time = get_current_logsystem_date_microsecond()
    local text = { }
    for i = 1, nargs do
      local arg = select(i, ...)

      if type(arg) == "table" and #arg > 0 then
        for i = 1, #arg do
          arg[i] = "\n[" .. time .. "]" .. arg[i]
        end
        arg = table.concat(arg)
      elseif type(arg) == "string" then
        arg = "\n[" .. time .. "]" .. arg
      else
        return fail("BAD_ARGUMENTS", "incorrect value of argument #" .. i)
      end

      text[i] = arg
    end
    text = table.concat(text)

    local cache = api_context:hiredis():history()
    try_unwrap(
        "INTERNAL_ERROR",
        cache:command("APPEND", transaction_id, text)
      )
  end

  local factory = function()

    return
    {
      try_get = try_get;
      try_append = try_append;
    }
  end

  -- TODO: its not work in standalone-services becuase they dont support zmq.
  -- https://redmine.iphonestudio.ru/issues/1472
  local system_action_handlers =
  {
    ["history.cache:append"] = function(api_context, transaction_id, text)
      spam("history.cache:append")

      -- TODO: LAZY HACK. This currently updates redis data
      --       once for each fork. It should do it once per save!
      api_context:ext("history.cache"):try_append(api_context, transaction_id, text)

      spam("/history.cache")

      return true
    end;
  }

  return
  {
    factory = factory;
    system_action_handlers = system_action_handlers;
  }
end)
