api:url "/sys/info"
{
  -- TODO: protect this from outside?
  doc:description [[System information]]
  [[
    Available as ${/:sys/info.xml} and ${/:sys/info.json}.
  ]];

  urls = -- TODO: ?! Why does this need custom format?
  {
    { url = "/sys/info.xml",  format = "xml" };
    { url = "/sys/info.json", format = "json" };
  };

  api:input { };

  api:output
  {
    output:ROOT_LIST "ok"
    {
      output:NUMBER "time_now";
      output:NUMBER "generation_time";
      output:LIST_NODE "node"
      {
        output:IDENTIFIER16 "name";
        output:IDENTIFIER16 "node_id";
        output:INTEGER "pid";
        output:NUMBER "time_start";
        output:NUMBER "time_now";
        output:OPTIONAL_NUMBER "time_shutdown";
        output:NUMBER "uptime";
        output:NUMBER "gc_count";
        output:INTEGER "requests_total";
        output:INTEGER "requests_fails";
        output:NUMBER "time_in_requests";
        output:NUMBER "time_idle";
        output:NUMBER "time_per_request_rolling_avg";
        output:NUMBER "time_per_request_max";
        output:NUMBER "time_per_request_min";
        output:NUMBER "info_staleness";
      };
    };
  };

  api:additional_errors { };

  api:handler (function(api_context, param)
    -- TODO: LAZY! Move to lua-nucleo
    local tkvlist_to_hash = function(t)
      local r = { }
      for i = 1, #t, 2 do
        r[t[i]] = t[i + 1]
      end
      return r
    end

    -- Note that send is non-blocking.
    local STALE_TTL = 60 -- In seconds

    -- Should be before system action.
    local result = { time_now = socket.gettime() }

    -- TODO: Do update on explicit request only (i.e. move it to a separate url)
    spam("updating service info for current node")
    try(
        "INTERNAL_ERROR",
        api_context:execute_system_action_on_current_node("update_service_info")
      )

    spam("processing service info for current node")
    local services = try_unwrap(
        "INTERNAL_ERROR",
        api_context:hiredis():system():command(
            "SMEMBERS", "pk-services:running"
          )
      )

    table.sort(services)

    for i = 1, #services do
      -- TODO: Shouldn't this explicitly handle missing items?
      local info = try_unwrap(
          "INTERNAL_ERROR",
          api_context:hiredis():system():command(
              "HGETALL", "pk-services:info:" .. services[i]
            )
        )
      if info and info ~= hiredis.NIL and next(info) ~= nil then
        info = tkvlist_to_hash(info)
        info.info_staleness = result.time_now - (tonumber(info.time_now) or 0)
        if info.info_staleness > STALE_TTL then
          -- TODO: Move purge to a separate request.
          log_error(
              "WARNING: purging stale running service", services[i],
              "updated", info.time_now, "now", result.time_now,
              "max ttl", STALE_TTL, "staleness", info.info_staleness
            )
          try_unwrap(
              "INTERNAL_ERROR",
              api_context:hiredis():system():command(
                  "SREM", "pk-services:running", services[i]
                )
            )
        else
          result[#result + 1] = info
        end
      else
        log_error("WARNING: no or empty info for running service", services[i])
        -- Ignoring, not purging: maybe info not uploaded yet
      end
    end

    result.generation_time = socket.gettime() - result.time_now

    return result
  end);
}
