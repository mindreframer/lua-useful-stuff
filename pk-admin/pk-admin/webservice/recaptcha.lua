--------------------------------------------------------------------------------
-- recaptcha.lua: wrapper for recaptcha (http://recaptcha.net)
-- This file is a part of pk-admin library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------

require("socket.http")

local arguments,
      optional_arguments,
      method_arguments
      = import 'lua-nucleo/args.lua'
      {
        'arguments',
        'optional_arguments',
        'method_arguments'
      }

local make_loggers
      = import 'pk-core/log.lua'
      {
        'make_loggers'
      }

--------------------------------------------------------------------------------

local log, dbg, spam, log_error = make_loggers("webservice/recaptcha", "WRC")

--------------------------------------------------------------------------------

local check_recaptcha = function(private_key, remote_ip, request_params)
  if not request_params then
    return false, "request_params not submitted"
  elseif not request_params.recaptcha_challenge_field then
    return false, "recaptcha_challenge_field not submitted"
  elseif not request_params.recaptcha_response_field then
    return false, "recaptcha_response_field not submitted"
  end

  local result, err = socket.http.request(
      "http://api-verify.recaptcha.net/verify",
      "privatekey=" .. private_key
   .. "&remoteip=" .. remote_ip
   .. "&challenge=" .. request_params.recaptcha_challenge_field
   .. "&response=" .. (request_params.recaptcha_response_field or "")
    )

  if not result then
    return false, err
  else
    if result == "true" then
      return true
    else
      result, err = string.match(result, "(%w+)\n(.*)")
      return (result and result=="true"), err
    end
  end
end

--------------------------------------------------------------------------------

return
{
  check_recaptcha = check_recaptcha;
}
