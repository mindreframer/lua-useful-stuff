--------------------------------------------------------------------------------
-- wsapi.lua: wsapi utilities
-- This file is a part of pk-engine library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------

local assert, tostring = assert, tostring
local coroutine_yield = coroutine.yield
local os_date = os.date

--------------------------------------------------------------------------------

local function wsapi_send(v)
  coroutine_yield(assert(tostring(v)))
  return wsapi_send
end

local append_no_cache_headers = function(headers)
  -- TODO: tdeepappend_defaults

  headers["Expires"] = headers["Expires"]
    or "Thu, 01 Jan 1970 00:00:00 GMT"

  headers["Last-Modified"] = headers["Last-Modified"]
    or os_date("!%a, %d %b %Y %H:%M:%S GMT")

  headers["Cache-Control"] = headers["Cache-Control"]
    or
    {
      "no-store, no-cache, must-revalidate";
      "post-check=0, pre-check=0"; -- IE-only, goes on a separate line
    }

  headers["Pragma"] = headers["Pragma"]
    or "no-cache"

  return headers
end

--------------------------------------------------------------------------------

return
{
  wsapi_send = wsapi_send;
  append_no_cache_headers = append_no_cache_headers;
}
