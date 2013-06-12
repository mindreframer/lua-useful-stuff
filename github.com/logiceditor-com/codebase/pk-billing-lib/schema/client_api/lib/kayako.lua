--------------------------------------------------------------------------------
-- kayako.lua
-- This file is a part of pk-billing-lib library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------


api:extend_context "kayako.helper" (function()
  local post_ticket = function(
      self,
      name,
      email,
      inv,
      text,
      game_name,
      tickettype,
      department,
      api_context
    )

    local gen_sign_data = function()
      math.randomseed(os.time())
      local crypto = require("crypto")
      local hmac = require("crypto.hmac")
      local salt = math.random(1024*1024*1024)
      local api_key = api_context:game_config().kayako_api_key
      local sign_key = api_context:game_config().kayako_sign_key
      local signature = base64.encode(hmac.digest("sha256", salt, sign_key, true))
      return "apikey=" .. api_key .. "&salt=" .. salt .. "&signature=" .. signature
    end

    local genurl_get = function(method)
      return api_context:game_config().kayako_server_url .. "?e=" .. method .. "&" .. gen_sign_data()
    end

    local genurl_post = function(method)
      return api_context:game_config().kayako_server_url .. "?e="..method
    end

    local get_post_data = function(arguments)
      local post_data = gen_sign_data()
      for k,v in pairs(arguments) do
        if #post_data ~= 0 then
          post_data = post_data .. "&"
        end
        post_data = ("%s%s=%s"):format(post_data, k, url_encode(tostring(v)))
      end
      return post_data
    end

    local http_post_data = function(url, data)
      local response_body, code = send_http_request(
          {
            url = url;
            method = "POST";
            headers =
            {
              ["Content-Type"] =  "application/x-www-form-urlencoded";
            };
            request_body = data;
          }
        )
      return response_body, code
    end

    local http_get_data = function(url)
      local response_body, code = send_http_request(
          {
            url = url;
            method = "GET";
          }
        )
      return response_body, code
    end

    local post_ticket_ = function(self, name, email, inv, text, game_name, tickettype, department)
      local full_text = (KAYAKO_TICKET_TEXT_FORMAT):format(inv, game_name, text)
      return http_post_data(
          genurl_post(KAYAKO_TICKET_METHOD),
          get_post_data(
              {
                subject = inv.."_"..name;
                fullname = name;
                email = email;
                departmentid = department;
                ticketstatusid = KAYAKO_TICKET_STATUS_ID;
                ticketpriorityid = KAYAKO_TICKET_PERIOD_ID;
                tickettypeid = tickettype;
                contents = full_text;
                autouserid = KAYAKO_TICKET_AUTO_USER_ID;
              }
            )
        )
    end
    return post_ticket_(self, name, email, inv, text, game_name, tickettype, department)
  end

  --Factory for kayako helper
  local factory = function()
    return
    {
      post_ticket = post_ticket;
    }
  end

  local system_action_handlers =
  {
    ["kayako.helper:post_ticket"] = function(api_context, request, paysystem)
      spam("kayako.helper:post_ticket")

      -- TODO: LAZY HACK. This currently updates redis data
      --       once for each fork. It should do it once per save!
      api_context:ext("kayako.helper"):create_form(api_context, request, paysystem)

      spam("/kayako.helper:post_ticket")

      return true
    end
  }

  return
  {
    factory = factory;
    system_action_handlers = system_action_handlers;
  }

end)
