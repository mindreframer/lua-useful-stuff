--------------------------------------------------------------------------------
-- request_queue.lua
-- This file is a part of pk-billing-lib library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------

api:export "lib/rq"
{
  exports =
  {
    --data
    "RH_REQUEST_QUEUE_KEY";

    --methods
    "rh_check_request";
  };

  handler = function()
    local json_util = require 'json.util'
    local json_decode = require 'json.decode'
    local json_decode_util = require 'json.decode.util'
    local json_encode = require 'json.encode'

    local RH_REQUEST_QUEUE_KEY = "request_queue:queue";

    -- TODO: generalize all create_*_request functions, reuse in all services
    local create_json_request = function(api_context, users)
      arguments(
          "table", api_context,
          "table", users
        )

      local res = try(
          "INTERNAL_ERROR",
          json_encode
          {
            query =
            {
              version = api_context:game_config().app_api_version;
              method = "check_account";
              uids = { users };
            }
          }
        )
      return res
    end

    local create_luabins_request = function(api_context, users)
      arguments(
          "table", api_context,
          "table", users
        )
      local payment = try(
          "INTERNAL_ERROR",
          luabins.save
          {
            query =
            {
              version = api_context:game_config().app_api_version;
              method = "check_account";
              uids = { users };
            }
          }
        )
      return payment
    end

    local create_xml_request = function(api_context, users)
      arguments(
          "table", api_context,
          "table", users
        )

      local cat, concat = make_concatter()
      cat [[<?xml version="1.0" encoding="UTF-8"?>
    <query version="]] (api_context:game_config().app_api_version) [[" method="payment">
      <uids>]]
      for i = 1, #users do
        local user = users[i]
        cat "<uid>"
        cdata_cat(cat, user.uid)
        cat "</uid>\n"
      end
      cat [[  </uids>
    </query>]]
      return concat()
    end

    -- TODO: make it work with multiuid requests ?
    local rh_check_account = function(api_context, appid, uid)
      arguments(
          "string", appid,
          "string", uid
        )
      local decode_options = json_util.merge(
          {
            object =
            {
              setObjectKey = json_decode_util.setObjectKeyForceNumber;
            };
          },
          json_decode.simple
        )

      local ltn12 = require 'ltn12'
      require 'socket.url'
      require 'socket.http'

      local app = try(
          "APP_NOT_FOUND",
          api_context:ext("settings.cache"):try_get_app(api_context, appid)
        )

      local request_body = ""

      if app.api.format == "json" then
        request_body = create_json_request(api_context, { id = uid })
      elseif app.api.format == "xml" then
        request_body = create_xml_request(api_context, { id = uid })
      elseif app.api.format == "luabins" then
        request_body = create_luabins_request(api_context, { id = uid })
      end

      -- TODO: use url params check
      -- TODO: generalize, make method in url optional
      local url = app.api.urls.check_account
      if app.api.use_url_query == true then
        url = url .. "?method=check_account";
      end

      local response_body = try(
          "EXTERNAL_ERROR",
          pkb_send_http_request(
              app,
              {
                url = url;
                method = "POST";
                request_body = request_body;
                headers =
                {
                  ["User-Agent"] = api_context:game_config().user_agent;
                };
              }
            )
        )

      -- use pcall for correct handle assert in json_decode function
      local ok, response = pcall(json_decode, response_body,  decode_options)
      if not ok then
        local err = response
        log("[check_account] request to url: ", url, "\nrequest body: ", request_body, "\nfailed to parse: ", response_body)
        return fail("PARSE_ERROR", err)
      elseif response == nil or response.error ~= nil or response.ok == nil then
        local err = "UNKNOWN"
        if response.error then
          err = response.error.id or "UNKNOWN"
        end
        log("[check_account] request to url: ", url, "\nrequest body: ", request_body, "\nresponse: ", response_body)
        return fail("EXTERNAL_ERROR", "[check_account] application return error: " .. err)
      end

      if not response.ok.present then
        return fail("ACCOUNT_NOT_FOUND", "[check_account] account " .. trim(uid) .. " not found in application " .. appid)
      end

      local present = tset(response.ok.present)

      local result = not not present[uid] and "OK" or "FAIL"
      log("[check_account]", result, uid, appid)

      return not not present[uid]
    end

    local rh_check_request = function(api_context, request)
      arguments(
          "table", api_context,
          "table", request
        )

      --check fields
      for i = 1, #PKB_REQUEST_FIELDS do
        local field = PKB_REQUEST_FIELDS[i]
        if not request[field] and not PKB_REQUEST_OPTIONAL_FIELDS[field] then
      return fail("INTERNAL_ERROR", "[check_request] field '" .. PKB_REQUEST_FIELDS[i] .. "' absent in request")
        end
      end

      --check account
      local res, err = rh_check_account(api_context, request.appid, request.uid)
      if not res then
        return fail("ACCOUNT_NOT_FOUND", "[check_request] Account " .. request.uid .. " not found")
      end

      --TODO: check amount
      return res and request or false, err
    end
  end
}

api:extend_context "request_queue.cache" (function()
  local try_get = function(self, api_context, request_id)
    method_arguments(
        self,
        "table", api_context,
        "string", request_id
      )

    local cache = api_context:hiredis():request_queue()

    local start = request_id:find("request:")
    if start == nil then
      request_id = "request:" .. request_id
    end

    -- get random request key from queue
    local request_data = try_unwrap(
        "INTERNA_ERROR",
         cache:command("HGETALL", request_id)
      )

    --create key=>value table with request
    local request = tkvlist2kvpairs(request_data)

    return request
  end

  local try_del = function(self, api_context, request_id)
    method_arguments(
        self,
        "table", api_context,
        "string", request_id
      )
    local cache = api_context:hiredis():request_queue()

    local start = request_id:find("request:")
    if start == nil then
      request_id = "request:" .. request_id
    end

    --remove request
    try_unwrap(
        "INTERNA_ERROR",
         cache:command("DEL", request_id)
      )
  end

  local try_pop = function(self, api_context, timeout)
    method_arguments(
        self,
        "table", api_context,
        "number", timeout
      )

    local cache = api_context:hiredis():request_queue()

    -- get random request key from queue
    local data = try_unwrap(
        "INTERNA_ERROR",
         cache:command("BLPOP", RH_REQUEST_QUEUE_KEY, timeout)
      )

    if data == hiredis.NIL then
      return nil, "Request queue are empty"
    end

    local value
    if is_table(data) then
      local value = data[2]
      local request = try_unwrap(
          "INTERNAL_ERROR",
           cache:command("HGETALL", value)
        )

      --create key => value table with request
      request = tkvlist2kvpairs(request)
      return value, request
    end
    return nil, "wrong redis response"
  end

  local try_get_length = function(self, api_context)
    method_arguments(
        self,
        "table", api_context
      )

    local cache = api_context:hiredis():request_queue()

    return try_unwrap(
        "INTERNA_ERROR",
        cache:command("SCARD", RH_REQUEST_QUEUE_KEY)
      )
  end

  local try_set = function(self, api_context, request)
    method_arguments(
        self,
        "table", api_context,
        "table", request
      )

    local request_ = { }
    for i = 1, #PKB_REQUEST_FIELDS do
      local key = PKB_REQUEST_FIELDS[i]

      if request[key] == nil and not PKB_REQUEST_OPTIONAL_FIELDS[key] then
        return fail("BAD_INPUT", "Value for '" .. key .. "' absent in request")
      end

      request_[key] = request[key]
    end
    request = request_

    stats_calc_counter(api_context, request.appid, request.paysystem_id, tonumber(request.status))

    local cache = api_context:hiredis():request_queue()
    local uuid = pkb_get_transaction_id()
    local request_id = "request:" .. uuid

    cache:append_command("MULTI")
    for key, value in pairs(request) do
      try_unwrap(
          "INTERNAL_ERROR",
          cache:append_command("HMSET", request_id, key, value)
        )
    end
    try_unwrap(
        "INTERNAL_ERROR",
        cache:append_command("RPUSH", RH_REQUEST_QUEUE_KEY, request_id)
      )
    cache:append_command("EXEC")

    try_unwrap("INTERNAL_ERROR", cache:get_reply()) --multi
    for key, value in pairs(request) do
      try_unwrap("INTERNAL_ERROR", cache:get_reply()) --hmset
    end
    try_unwrap("INTERNAL_ERROR", cache:get_reply()) --rpush
    try_unwrap("INTERNAL_ERROR", cache:get_reply()) --exec

--dont use thread cache
--    self.cache_[pkkey] = request
    return uuid
  end

  local factory = function()

    return
    {
      try_get = try_get;
      try_del = try_del;
      try_pop = try_pop;
      length = try_get_length;
      try_set = try_set;
    }
  end

  -- TODO: its not work in standalone-services becuase they dont support zmq.
  -- https://redmine.iphonestudio.ru/issues/1472
  local system_action_handlers =
  {
    ["request_queue.cache:set"] = function(api_context, request)
      spam("request_queue.cache:set")

      -- TODO: LAZY HACK. This currently updates redis data
      --       once for each fork. It should do it once per save!
      local id = api_context:ext("request_queue.cache"):try_set(api_context, request)

      spam("/request_queue.cache")

      return id
    end;
  }

  return
  {
    factory = factory;
    system_action_handlers = system_action_handlers;
  }
end)
