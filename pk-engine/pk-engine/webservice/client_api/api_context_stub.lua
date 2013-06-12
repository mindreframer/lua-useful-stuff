--------------------------------------------------------------------------------
-- api_context_stub.lua: handler context wrapper for api (without wsapi)
-- This file is a part of pk-engine library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------
-- NOTE: When changing, remember to change api_context as well
--------------------------------------------------------------------------------

local socket = require 'socket'
require 'socket.url'
local posix = require 'posix'

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

local make_net_connection_manager
      = import 'pk-engine/net/net_connection_manager.lua'
      {
        'make_net_connection_manager'
      }

local make_db_connection_manager
      = import 'pk-engine/db/db_connection_manager.lua'
      {
        'make_db_connection_manager'
      }

local make_db_manager
      = import 'pk-engine/db/db_manager.lua'
      {
        'make_db_manager'
      }

local make_redis_manager,
      make_redis_connection_manager
      = import 'pk-engine/redis/redis_manager.lua'
      {
        'make_redis_manager',
        'make_redis_connection_manager'
      }

local make_hiredis_manager,
      make_hiredis_connection_manager
      = import 'pk-engine/hiredis/hiredis_manager.lua'
      {
        'make_hiredis_manager',
        'make_hiredis_connection_manager'
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
    "webservice/client_api/api_context_stub", "APS"
  )

--------------------------------------------------------------------------------

-- WARNING: Call methods of the context inside call() protection only!
-- NOTE: It is OK to create context object outside of call() protection.
local make_api_context_stub
do
  -- NOTE: When changing this, remember to change request_manager.lua as well!
  local get_context_stub = function(config_manager)
    arguments(
        "table", config_manager
      )

    return setmetatable( -- TODO: Cache
        { },
        {
          __index =
          {
            config_manager = config_manager;
            net_connection_manager = make_net_connection_manager();
            db_manager = make_db_manager(
                config_manager,
                make_db_connection_manager()
              );
            redis_manager = make_redis_manager(
                config_manager,
                make_redis_connection_manager()
              );
            hiredis_manager = make_hiredis_manager(
                config_manager,
                make_hiredis_connection_manager()
              );
          };
          __metatable = "context_stub";
        }
      )
  end

  -- Private method
  local get_cached_request = function(self)
    method_arguments(self)
    if not self.cached_request_ then
      fail("INTERNAL_ERROR", "can't get cached_request: have no wsapi")
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
    -- TODO: Should this use param_stack?!
    return self.param_stack_[#self.param_stack_]
        or get_cached_request(self).GET
  end

  local get_cookie = function(self, name)
    method_arguments(
        self,
        "string", name
      )
    -- TODO: ?!
    error("no cookies, this is a stub context")
  end

  local set_cookie = function(self, name, value)
    method_arguments(
        self,
        "string", name
        -- value may be string or table
      )
    -- TODO: ?!
    error("no cookies, this is a stub context")
  end

  local delete_cookie = function(self, name, path)
    method_arguments(
        self,
        "string", name
      )
    optional_arguments(
        "string", path
      )

    -- TODO: ?!
    error("no cookies, this is a stub context")
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
    fail("INTERNAL_ERROR", "can't get request_ip: have no wsapi")
  end

  local request_user_agent = function(self)
    method_arguments(self)
    fail("INTERNAL_ERROR", "can't get request_user_agent: have no wsapi")
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
    method_arguments(
        self,
        --"any", key,
        "function", factory
      )
    assert(key ~= nil)

    log("registering context extension:", key)

    assert(self.ext_factories_[key] == nil)
    self.ext_factories_[key] = factory
  end

  local ext = function(self, key)
    method_arguments(
        self
        --"any", key
      )
    local v = self.extensions_[key]

    -- TODO: Use metatable!
    if not v then
      log("creating context extension object", key)

      local factory = self.ext_factories_[key]
      if not factory then
        error("unknown context extension: " .. tostring(key), 2)
      end

      v = factory(self.ext_getter_)
      self.extensions_[key] = v
    end

    return v
  end

  local execute_system_action_on_current_node = function()
    error("TODO: Implement execute_system_action_on_current_node if needed")
  end

  make_api_context_stub = function(
      internal_config_manager,
      db_tables,
      www_game_config_getter,
      www_admin_config_getter,
      internal_call_handlers
    )
    arguments(
        "table",    internal_config_manager,
        "table",    db_tables,
        "function", www_admin_config_getter,
        "function", www_game_config_getter,
        "table",    internal_call_handlers
      )

    local self =
    {
      raw_internal_config_manager = raw_internal_config_manager;
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
      --
      get_cookie = get_cookie;
      set_cookie = set_cookie;
      delete_cookie = delete_cookie;
      --
      extend = extend;
      ext = ext;
      --
      execute_system_action_on_current_node =
        execute_system_action_on_current_node;
      --
      push_param = push_param; -- Private
      pop_param = pop_param; -- Private
      --
      destroy = destroy; -- Private
      --
      -- WARNING: Do not expose this variable (see push/pop_param).
      context_ = get_context_stub(internal_config_manager);
      --
      cached_request_ = nil;
      cached_game_config_ = nil;
      cached_admin_config_ = nil;
      cached_db_ = nil;
      cached_redis_ = nil;
      cached_hiredis_ = nil;
      --
      extensions_ = { };
      ext_factories_ = { };
      ext_getter_ = nil;
      --
      tables_ = db_tables;
      www_game_config_getter_ = www_game_config_getter;
      www_admin_config_getter_ = www_admin_config_getter;
      internal_call_handlers_ = internal_call_handlers;
      --
      param_stack_ = { };
      --
      time_start_ = socket.gettime();
    }

    -- TODO: Ugly.
    self.ext_getter_ = function(...)
      return self:ext(...)
    end

    return self
  end
end

--------------------------------------------------------------------------------

local common_make_api_context_stub
do

  local default_game_config_getter = function()
    return fail("INTERNAL_ERROR", "no www application config here")
  end

  local default_admin_config_getter = function()
    return fail("INTERNAL_ERROR", "no www admin config here")
  end

  common_make_api_context_stub = function(
      internal_config_manager,
      db_tables,
      www_game_config_getter,
      www_admin_config_getter,
      internal_call_handlers
    )
    db_tables = db_tables or { }

    www_game_config_getter = www_game_config_getter or default_game_config_getter

    www_admin_config_getter = www_admin_config_getter or default_admin_config_getter

    internal_call_handlers = internal_call_handlers or { }

    arguments(
        "table",    internal_config_manager,
        "table",    db_tables,
        "function", www_admin_config_getter,
        "function", www_game_config_getter,
        "table",    internal_call_handlers
      )

    return make_api_context_stub(
        internal_config_manager,
        db_tables,
        www_game_config_getter,
        www_admin_config_getter,
        internal_call_handlers
      )
  end
end

--------------------------------------------------------------------------------

return
{
  make_api_context_stub = make_api_context_stub;
  common_make_api_context_stub = common_make_api_context_stub;
}
