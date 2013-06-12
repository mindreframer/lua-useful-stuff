--------------------------------------------------------------------------------
-- api_context.lua: handler context wrapper for api
-- This file is a part of pk-engine library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------
-- NOTE: When changing, remember to change api_context_stub.lua as well
--------------------------------------------------------------------------------

require 'wsapi.request'
require 'socket.url'
require 'wsapi.util'

--------------------------------------------------------------------------------

local arguments,
      optional_arguments,
      method_arguments
      = import 'lua-nucleo/args.lua'
      {
        'arguments',
        'optional_arguments',
        'method_arguments'
      }

local is_string
      = import 'lua-nucleo/type.lua'
      {
        'is_string'
      }

local make_loggers
      = import 'pk-core/log.lua'
      {
        'make_loggers'
      }

local try,
      fail
      = import 'pk-core/error.lua'
      {
        'try',
        'fail'
      }

local make_api_db,
      destroy_api_db
      = import 'pk-engine/webservice/client_api/api_db.lua'
      {
        'make_api_db',
        'destroy_api_db'
      }

local make_api_redis,
      destroy_api_redis
      = import 'pk-engine/webservice/client_api/api_redis.lua'
      {
        'make_api_redis',
        'destroy_api_redis'
      }

local make_api_hiredis,
      destroy_api_hiredis
      = import 'pk-engine/webservice/client_api/api_hiredis.lua'
      {
        'make_api_hiredis',
        'destroy_api_hiredis'
      }

--------------------------------------------------------------------------------

local log, dbg, spam, log_error = make_loggers(
    "webservice/client_api/api_context", "APC"
  )

--------------------------------------------------------------------------------

-- WARNING: Call methods of the context inside call() protection only!
-- NOTE: It is OK to create context object outside of call() protection.
local make_api_context
do
  -- Private method
  local get_cached_request = function(self)
    method_arguments(self)
    if not self.cached_request_ then
      self.new_wsapi_env = wsapi.util.make_rewindable(self.context_.wsapi_env)
      self.cached_request_ = wsapi.request.new(
          self.new_wsapi_env,
          { overwrite = true }
        )
    end
    return self.cached_request_
  end

  -- Private method
  local get_cached_db = function(self)
    method_arguments(self)
    if not self.cached_db_ then
      self.cached_db_ = make_api_db(self.tables_, self.context_.db_manager)
    end
    return self.cached_db_
  end

  -- Private method
  local get_cached_redis = function(self)
    method_arguments(self)
    if not self.cached_redis_ then
      self.cached_redis_ = make_api_redis(self.context_.redis_manager)
    end
    return self.cached_redis_
  end

  -- Private method
  local get_cached_hiredis = function(self)
    method_arguments(self)
    if not self.cached_hiredis_ then
      self.cached_hiredis_ = make_api_hiredis(self.context_.hiredis_manager)
    end
    return self.cached_hiredis_
  end

  local post_request = function(self)
    method_arguments(self)
    return self.param_stack_[#self.param_stack_]
        or get_cached_request(self).POST
  end

  local get_request = function(self)
    method_arguments(self)
    return self.param_stack_[#self.param_stack_] -- TODO: Should this use param_stack?!
        or get_cached_request(self).GET
  end

  local raw_internal_config_manager = function(self)
    method_arguments(self)
    return self.context_.config_manager
  end

  -- Private method
  local get_cached_game_config = function(self)
    method_arguments(self)
    if not self.cached_game_config_ then
      self.cached_game_config_ = try(
          "INTERNAL_ERROR",
          self.www_game_config_getter_(self.context_)
        )
    end
    return self.cached_game_config_
  end

  local game_config = function(self)
    method_arguments(self)
    return get_cached_game_config(self)
  end

  -- Private method
  local get_cached_admin_config = function(self)
    method_arguments(self)
    if not self.cached_admin_config_ then
      self.cached_admin_config_ = try(
          "INTERNAL_ERROR",
          self.www_admin_config_getter_(self.context_)
        )
    end
    return self.cached_admin_config_
  end

  local admin_config = function(self)
    method_arguments(self)
    return get_cached_admin_config(self)
  end

  local request_ip = function(self)
    method_arguments(self)

    -- WARNING: This function should not fail even if IP is unknown!

    -- TODO: If REMOTE_ADDR does not exist or is empty,
    --       or starts with '127', '10.' or '192',
    --       try to look into X-Forwarded-For header.

    local wsapi_env = self.context_.wsapi_env
    local ip = wsapi_env["X-REAL-IP"]

    if not ip or ip == "" then
      ip = wsapi_env["X-FORWARDED-FOR"]
      if ip then
        ip = ip:match("^(.-),.*$")
      end
    end

    if not ip or ip == "" then
      ip = wsapi_env["REMOTE_ADDR"]
    end

    if not ip then
      ip = ""
    end

    return ip
  end

  local request_user_agent = function(self)
    method_arguments(self)

    -- WARNING: This function should not fail even if UA is unknown!

    return self.context_.wsapi_env["HTTP_USER_AGENT"] or ""
  end

  -- Note that we do not have anything destroyable (yet)
  -- that is not destroys itself in __gc. So no __gc here.
  -- All is done on lower level if user forgets to call destroy().
  local destroy = function(self)
    method_arguments(self)

    -- Not using get_cached_db() since we don't want to create db
    -- if it was not used
    if self.cached_db_ then
      destroy_api_db(self.cached_db_)
      self.cached_db_ = nil
    end

    -- Not using get_cached_redis() since we don't want to create redis
    -- if it was not used
    if self.cached_redis_ then
      destroy_api_redis(self.cached_redis_)
      self.cached_redis_ = nil
    end

    -- Not using get_cached_hiredis() since we don't want to create hiredis
    -- if it was not used
    if self.cached_hiredis_ then
      destroy_api_hiredis(self.cached_hiredis_)
      self.cached_hiredis_ = nil
    end

    assert(#self.param_stack_ == 0, "unbalanced param stack on destroy")
  end

  local db = function(self)
    method_arguments(self)
    return get_cached_db(self)
  end

  local redis = function(self)
    method_arguments(self)
    return get_cached_redis(self)
  end

  local hiredis = function(self)
    method_arguments(self)
    return get_cached_hiredis(self)
  end

  local handle_url = function(self, url, param)
    method_arguments(
        self,
        "string", url,
        "string", param
      )
    local handler = self.internal_call_handlers_[url]
    if not handler then
      return fail(
          "INTERNAL_ERROR",
          "internal call handler for " .. url .. " not found"
        )
    end

    local res, err, err_id = handler(self, param)

    return res, err, err_id
  end

  local push_param
  do
    -- Based on WSAPI 1.3.4 (in override mode)
    -- TODO: Reuse WSAPI version instead
    local function parse_qs(qs, t)
      t = t or { }
      local url_decode = socket.url.unescape
      for key, val in qs:gmatch("([^&=]+)=([^&=]*)&?") do
        t[url_decode(key)] = url_decode(val)
      end
      return t
    end

    push_param = function(self, param)
      if is_string(param) then
        param = parse_qs(param)
      end
      method_arguments(
          self,
          "table", param
        )
      table.insert(self.param_stack_, param)
    end
  end

  local pop_param = function(self)
    method_arguments(self)
    try("INTERNAL_ERROR", #self.param_stack_ > 0, "no more params to pop")
    return table.remove(self.param_stack_)
  end

  local extend = function(self, key, factory)
    return self.context_:ext(key, factory)
  end

  local ext = function(self, key)
    return self.context_:ext(key)
  end

  local get_cookie = function(self, name)
    method_arguments(
        self,
        "string", name
      )
    -- TODO: How should this interact with param_stack?
    return get_cached_request(self).cookies[name]
  end

  local set_cookie = function(self, name, value)
    method_arguments(
        self,
        "string", name
        -- value may be string or table
      )
    -- TODO: How should this interact with param_stack?
    self.context_.wsapi_response:set_cookie(name, value)
  end

  local delete_cookie = function(self, name, path)
    method_arguments(
        self,
        "string", name
      )
    optional_arguments(
        "string", path
      )
    -- TODO: How should this interact with param_stack?
    self.context_.wsapi_response:delete_cookie(name, path)
  end

  local get_cookies = function(self)
    method_arguments(self)

    if self.cached_cookies_ == nil then
      local cookies = { }
      local cookies_ = string.gsub(";" .. (get_cached_request(self).env.HTTP_COOKIE or "") .. ";", "%s*;%s*", ";")
      local pattern = ";([%a%d-_]+)=(.-);"
      local name, cookie, init = '', '', 1

      while (true) do
        name, cookie = string.match(cookies_, pattern, init)
        if name == nil or cookie == nil then
          break;
        end
        rawset(cookies, wsapi.util.url_decode(name), wsapi.util.url_decode(cookie))
        init = init + #name + #cookie
      end

      self.cached_cookies_ = cookies
    end

    return self.cached_cookies_
  end

  local execute_system_action_on_current_node = function(self, action, ...)
    method_arguments(
        self,
        "string", action
      )
    -- TODO: Lazy hack.

    local res, err = self:ext(
        "current_node_system_action_executor"
      ):execute(action, ...)
    if res == nil then
      return
          nil,
          "failed to execute current node system action: " .. tostring(err)
    end

    local res, err = self:ext(
        "current_process_system_action_executor"
      ):execute(action, ...)
    if res == nil then
      return
          nil,
          "failed to execute current process system action: " .. tostring(err)
    end

    return res -- TODO: Support multiple return values?
  end

  -- TODO: Hack. Should not be available to public.
  local raw_redis_manager = function(self)
    return self.context_.redis_manager
  end

  local get_raw_postdata = function(self)
    if self.cached_postdata_ == nil then
      self.new_wsapi_env.input:rewind()
      self.cached_cookies_ = self.new_wsapi_env.input:read(self.context_.wsapi_env.input.length)
    end
    return self.cached_cookies_
  end

  local get_request_method = function(self)
    return get_cached_request(self).method
  end

  make_api_context = function(
      context,
      db_tables,
      www_game_config_getter,
      www_admin_config_getter,
      internal_call_handlers
    )
    arguments(
        "table",    context,
        "table",    db_tables,
        "function", www_admin_config_getter,
        "function", www_game_config_getter,
        "table",    internal_call_handlers
      )

    return
    {
      raw_internal_config_manager = raw_internal_config_manager;
      raw_redis_manager = raw_redis_manager;
      handle_url = handle_url;
      --
      game_config = game_config;
      admin_config = admin_config;
      db = db;
      redis = redis;
      hiredis = hiredis;
      --
      request_ip = request_ip;
      request_user_agent = request_user_agent;
      post_request = post_request;
      get_request = get_request;
      get_request_method = get_request_method;
      --
      get_cookie = get_cookie;
      set_cookie = set_cookie;
      delete_cookie = delete_cookie;
      get_cookies = get_cookies;
      --
      get_raw_postdata = get_raw_postdata;
      --
      extend = extend;
      ext = ext;
      --
      execute_system_action_on_current_node
        = execute_system_action_on_current_node;
      --
      push_param = push_param; -- Private
      pop_param = pop_param; -- Private
      --
      destroy = destroy; -- Private
      --
      -- WARNING: Do not expose this variable (see push/pop_param).
      context_ = context;
      new_wsapi_env = nil;
      --
      cached_request_ = nil;
      cached_game_config_ = nil;
      cached_admin_config_ = nil;
      cached_db_ = nil;
      cached_redis_ = nil;
      cached_hiredis_ = nil;
      cached_cookies_ = nil;
      cached_postdata_ = nil;
      --
      tables_ = db_tables;
      www_game_config_getter_ = www_game_config_getter;
      www_admin_config_getter_ = www_admin_config_getter;
      internal_call_handlers_ = internal_call_handlers;
      --
      extensions_ = { };
      ext_factories_ = { };
      --
      param_stack_ = { };
    }
  end
end

--------------------------------------------------------------------------------

return
{
  make_api_context = make_api_context;
}
