--------------------------------------------------------------------------------
-- stats.lua
-- This file is a part of pk-billing-lib library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------

api:export "lib/stats"
{
  exports =
  {
    "stats_calc_counter";
    "stats_get_counter";
  };

  handler = function()
    local STATS_COUNTER_KEY = "counter:app:"

    local stats_get_counter_key = function(appid, paysystem_id)
      arguments(
          "string", appid
        )
      appid = pkb_parse_pkkey(appid) or appid

      return STATS_COUNTER_KEY .. appid .. ":" .. paysystem_id
    end

    local stats_get_counter = function(api_context, appid, paysystem_id)
      arguments(
          "table", api_context,
          "string", appid,
          "string", paysystem_id
        )

      local cache = api_context:hiredis():stats()
      local counter_key = stats_get_counter_key(appid, paysystem_id)

      local allowed_status = tset(PKB_TRANSACTION_STATUS)

      local stats = try_unwrap(
          "INTERNAL_ERROR",
          cache:command("HGETALL", counter_key)
        )
      if not stats or #stats == 0 then
        return { }
      end

      stats = tkvlist2kvpairs(stats)
      local statuses = { }
      for status, value in pairs(stats) do
        local status_data = split_by_char(status, ":")
        if not status_data or #status_data ~= 2 or status_data[1] ~= "status" then
          return nil, "Incorrect status key: " .. status
        end
        local status_id = tonumber(status_data[2])
        if not allowed_status[status_id] then
          return nil, "Unknown status: " .. status_data[2]
        end

        statuses[status_id] = tonumber(value)
      end

      return statuses
    end

    local stats_calc_counter = function(api_context, appid, paysystem_id, new_status, old_status)
      arguments(
          "table", api_context,
          "string", appid,
          "string", paysystem_id,
          "number", new_status
        )

      local allowed_status = tset(PKB_TRANSACTION_STATUS)

      if old_status then
        arguments("number", old_status)
        if not allowed_status[old_status] then
          return nil, "Not allowed old status: " .. tostring(old_status)
        end
      end
      if not allowed_status[new_status] then
        return nil, "Not allowed new status: " .. tostring(new_status)
      end

      local cache = api_context:hiredis():stats()
      local counter_key = stats_get_counter_key(appid, paysystem_id)

      if old_status then
        try_unwrap(
            "INTERNAL_ERROR",
            cache:command("HINCRBY", counter_key, "status:" .. tostring(old_status), -1)
          )
      end
      try_unwrap(
          "INTERNAL_ERROR",
          cache:command("HINCRBY", counter_key, "status:" .. tostring(new_status), 1)
        )
    end
  end;
}
