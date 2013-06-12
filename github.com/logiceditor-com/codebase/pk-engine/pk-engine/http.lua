--------------------------------------------------------------------------------
-- http.lua - work with http/https requests
-- This file is a part of pk-engine library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------

local log, dbg, spam, log_error = import 'pk-core/log.lua' { 'make_loggers' } (
    "http.lua", "HTP"
  )

--------------------------------------------------------------------------------

local table_concat = table.concat

local arguments,
      optional_arguments,
      method_arguments
      = import 'lua-nucleo/args.lua'
      {
        'arguments',
        'optional_arguments',
        'method_arguments'
      }

local is_table
      = import 'lua-nucleo/type.lua'
      {
        'is_table'
      }

local tset,
      toverride_many
      = import 'lua-nucleo/table-utils.lua'
      {
        'tset',
        'toverride_many'
      }

--------------------------------------------------------------------------------

local socket = require "socket"
require "socket.http"
require "socket.url"
local ssl = require "ssl"
require "ssl.https"
local ltn12 = require "ltn12"

--------------------------------------------------------------------------------

local send_http_request, common_send_http_request, is_http_error_code
do
  local REDIRECT_CODES = tset { 301, 302, 307 }
  local ALLOWED_METHODS = tset { "POST", "GET" }
  local METHOD_HEADERS =
  {
    ["POST"] =
    {
      ["Content-Type"] =  "application/x-www-form-urlencoded";
    };
    ["GET"] = { };
  }
  local MAX_REDIRECT_LEVEL = 16
  local REQUEST_FIELDS_LIST = { "url", "method", "request_body", "headers", "ssl_options" }
  local OPTIONAL_REQUEST_FIELDS_LIST = tset { "request_body", "headers", "ssl_options" }

  local is_http_error_code = function(code)
    arguments(
        "number", code
      )
    return code >= 400 and code <= 599
  end

  local impl = function(url, method, headers, request_body, ssl_options)
    arguments(
        "string", url,
        "string", method,
        "table", headers,
        "string", request_body,
        "table", ssl_options
      )

    local response_body = { }

    local parsed_url = socket.url.parse(url)
    if not is_table(parsed_url) then
      return nil, "failed to parse url: " .. url
    end
    local uri_scheme = parsed_url.scheme

    if uri_scheme == nil then
      return nil, "URI scheme not defined"
    end
    uri_scheme = uri_scheme:lower()

    local res, code, response_headers
    if uri_scheme == "http" then
      res, code, response_headers = socket.http.request
      {
        url = url;
        method = method;
        headers = headers;
        source = ltn12.source.string(request_body);
        sink = ltn12.sink.table(response_body);
      }
    elseif uri_scheme == "https" then
      local request =
      {
        url = url;
        method = method;
        headers = headers;
        source = ltn12.source.string(request_body);
        sink = ltn12.sink.table(response_body);
      }

      -- luasec require to specify both options: key and certificate
      -- documentation: http://www.inf.puc-rio.br/~brunoos/luasec/reference.html
      -- key - path to the file that contains the key (in PEM format).
      -- certificate - Path to the file that contains the chain certificates. These must be in
      --   PEM format and must be sorted starting from the subject's certificate (client or server),
      --   followed by intermediate CA certificates if applicable, and ending at the highest level CA.
      if ssl_options.key == nil and ssl_options.certificate ~= nil
        or ssl_options.key ~= nil and ssl_options.certificate == nil
      then
        ssl_options.key = ssl_options.certificate or ssl_options.key
        ssl_options.certificate = ssl_options.key or ssl_options.certificate
      end

      request = toverride_many(request, ssl_options)
      res, code, response_headers = ssl.https.request(request)
    else
      return nil, "unsupported scheme: " .. tostring(uri_scheme)
    end

    return res, code, response_headers, response_body
  end

  local common_impl = function(request, check_response_code)
    arguments(
        "table", request,
        "boolean", check_response_code
      )

    for i = 1, #REQUEST_FIELDS_LIST do
      local field = REQUEST_FIELDS_LIST[i]
      if request[field] == nil and not OPTIONAL_REQUEST_FIELDS_LIST[field] then
        return nil, "Field " .. field .. " absent in request"
      end
    end

    local url = request.url
    local method = request.method:upper()
    if not ALLOWED_METHODS[method] then
      return nil, "Unknown method: " .. method
    end
    local ssl_options = request.ssl_options or { }
    local request_body = request.request_body or ""

    local request_headers =
    {
      ["Content-Length"] = #request_body;
    }
    request_headers = toverride_many(request_headers, METHOD_HEADERS[method])
    if is_table(request.headers) then
      request_headers = toverride_many(request_headers, request.header)
    end

    local redirect_level = 1
    local result, code, response_headers, response_body
    while REDIRECT_CODES[code] or redirect_level == 1 do
      if redirect_level > MAX_REDIRECT_LEVEL then
        break
      end

      result, code, response_headers, response_body = impl(
          url, method, request_headers, request_body, ssl_options
        )
      if result == nil then
        local err = code
        return nil, err
      elseif check_response_code and is_http_error_code(code) then
        return nil, "ger error code '" .. tostring(code) .. "' on request to url: " .. url
      end

      url = response_headers.location -- maybe nil if code not in redirect_code
      redirect_level = redirect_level + 1
    end

    return is_table(response_body)
        and table_concat(response_body)
          or response_body,
      code,
      response_headers
  end

  send_http_request = function(request)
    arguments(
        "table", request
      )

    return common_impl(request, false)
  end

  common_send_http_request = function(request)
    arguments(
        "table", request
      )

    return common_impl(request, true)
  end
end

return
{
  is_http_error_code = is_http_error_code;
  common_send_http_request = common_send_http_request;
  send_http_request= send_http_request;
}
