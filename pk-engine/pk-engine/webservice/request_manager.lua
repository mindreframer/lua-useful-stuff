--------------------------------------------------------------------------------
-- request_manager.lua: wsapi request manager
-- This file is a part of pk-engine library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------

local socket = require 'socket'
require 'wsapi.request'
require 'wsapi.response'

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

local is_number,
      is_string,
      is_function,
      is_table
      = import 'lua-nucleo/type.lua'
      {
        'is_number',
        'is_string',
        'is_function',
        'is_table'
      }

local assert_is_number,
      assert_is_table,
      assert_is_function
      = import 'lua-nucleo/typeassert.lua'
      {
        'assert_is_number',
        'assert_is_table',
        'assert_is_function'
      }

local invariant
      = import 'lua-nucleo/functional.lua'
      {
        'invariant'
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

local make_default_config_manager
      = import 'pk-engine/srv/internal_config/client.lua'
      {
        'make_config_manager'
      }

local make_loggers
      = import 'pk-core/log.lua'
      {
        'make_loggers'
      }

local wsapi_send,
      append_no_cache_headers
      = import 'pk-engine/webservice/wsapi.lua'
      {
        'wsapi_send',
        'append_no_cache_headers'
      }

local text_response
      = import 'pk-engine/webservice/response.lua'
      {
        'text_response'
      }

--------------------------------------------------------------------------------

local log, dbg, spam, log_error = make_loggers("request_manager", "RMN")

--------------------------------------------------------------------------------

local handler_404 = function(context)
  log("404", context.wsapi_env.PATH_INFO)
  return text_response("404 Not Found", nil, 404)
end

--------------------------------------------------------------------------------

local make_filesystem_request_handler
do
  local handle_request = function(self, context)
    method_arguments(
        self,
        "table", context
      )

    local handler = self.handlers_[context.wsapi_env.PATH_INFO] or handler_404
    return handler(context)
  end

  make_filesystem_request_handler = function(url_to_handler, path_pattern)
    path_pattern = path_pattern or "handlers%s.lua"

    arguments(
        "table", url_to_handler,
        "string", path_pattern
      )

    local handlers = { }

    for path_info, handler_file in pairs(url_to_handler) do
      if is_number(path_info) then
        path_info = handler_file
      end

      handlers[path_info] = import(path_pattern:format(handler_file))
      {
        'handle'
      }
    end

    return
    {
      handle_request = handle_request;
      --
      handlers_ = handlers;
    }
  end
end

--------------------------------------------------------------------------------

local make_request_manager
do
  local get_context -- NOTE: When changing this, remember to change api_context_stub.lua as well!
  do
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

    local create_common_context = function(
        wsapi_env,
        config_manager_maker
      )
      arguments(
          "table", wsapi_env,
          "function", config_manager_maker
        )

      local config_host = wsapi_env.PK_CONFIG_HOST
      local config_port = tonumber(wsapi_env.PK_CONFIG_PORT)

      if not config_host or not config_port then
        log_error(
              "bad wsapi_env",
              "PK_CONFIG_HOST:", wsapi_env.PK_CONFIG_HOST,
              "PK_CONFIG_PORT:", wsapi_env.PK_CONFIG_PORT,
              "all:", wsapi_env
            )
        error("missing config host and/or port")
      end

      local config_manager = config_manager_maker(config_host, config_port)

      local self =
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
        --
        extend = extend;
        ext = ext;
        --
        extensions_ = { };
        ext_factories_ = { };
        ext_getter_ = nil;
      }

      -- TODO: Ugly.
      self.ext_getter_ = function(...)
        return self:ext(...)
      end

      return self
    end

    -- Returned context is guaranteed to be single-use data.
    -- Feel free to change it (just don't touch the metatable and wsapi_env).
    -- TODO: Remove restriction on wsapi_env
    get_context = function(self, wsapi_env)
      method_arguments(
          self,
          "table", wsapi_env
        )

      if not self.common_context_mt_ then
        self.common_context_mt_ =
        {
          __index = create_common_context(
              wsapi_env,
              self.config_manager_maker_
            );
          __metatable = true;
        }
      end

      local context = setmetatable(
          {
            wsapi_env = wsapi_env;
            wsapi_response = wsapi.response.new();
          },
          self.common_context_mt_
        )

      -- Hack. Remove this limitation.
      assert(context.wsapi_env == wsapi_env)

      return context
    end
  end

  local extend_context = function(self, wsapi_env, key, factory)
    return get_context(
        self, wsapi_env
      ):extend(
        key, factory
      )
  end

  local get_context_extension = function(self, wsapi_env, key)
    return get_context(
        self, wsapi_env
      ):ext(
        key
      )
  end

  local handle_request
  do
    local error_handler = function(msg)
      log_error(debug.traceback(msg, 2))
      return msg
    end

    handle_request = function(self, wsapi_env)
      method_arguments(
          self,
          "table", wsapi_env
        )

      self.requests_total_ = self.requests_total_ + 1

      local time_start = socket.gettime()
      local gc_start = collectgarbage("count")

      local context = get_context(self, wsapi_env)
      local ok, status, body, headers = xpcall(
          function()
            local status, body, headers = self.request_handler_:handle_request(
                context
              )

            assert_is_number(status, "bad response status code")
            assert(is_function(body) or is_string(body), "bad response body")
            assert(
                is_table(headers) or is_string(headers),
                "bad response headers"
              )

            return status, body, headers
          end,
          error_handler
        )

      if not ok then
        -- NOTE: Error is already logged in error_handler.
        self.requests_fails_ = self.requests_fails_ + 1

        -- Using text_response()
        -- only because it is used everywhere else
        status, body, headers = text_response(
            "500 Internal Error",
            nil,
            500
          )
      end

      -- WARNING: If body is a function, provided by handler,
      --          it MUST NOT crash, or user will see error message!

      if is_string(headers) then
        headers = append_no_cache_headers
        {
          ["Content-Type"] = headers;
        }
      end

      for k, v in pairs(headers) do
        -- TODO: Normalize header capitalization!
        context.wsapi_response.headers[k] = v
      end

      -- WARNING! Do not uncomment! Too much spamming on heavy load!
      -- log(status, context.wsapi_env.PATH_INFO)

      -- TODO: Set these through response instead?
      --       This response object is here only because of cookies.
      context.wsapi_response.status = status
      context.wsapi_response:write(body)

      local time_end = socket.gettime()
      local gc_end = collectgarbage("count")

      local time_in_request = time_end - time_start

      self.time_in_requests_ = self.time_in_requests_ + time_in_request
      self.time_per_request_min_ = math.min(
          self.time_per_request_min_,
          time_in_request
        )
      self.time_per_request_max_ = math.max(
          self.time_per_request_max_,
          time_in_request
        )
      self.time_per_request_rolling_avg_ =
        0.01 * time_in_request +
        0.99 * self.time_per_request_rolling_avg_

      -- TODO: Add GC to stats!

      -- TODO: Make limit configurable!
      if time_end - time_start > 0.5 then
        log_error(
            "WARNING: slow request",
            ("%04.2fs:"):format(time_end - time_start),
            "GC", gc_end - gc_start, "=", gc_end, "-", gc_start, "KB",
            context.wsapi_env.PATH_INFO, context.wsapi_env
          )
      end

      return context.wsapi_response:finish()
    end
  end

  local get_service_info = function(self)
    method_arguments(self)

    local now = socket.gettime()

    return
    {
      name = self.service_name_;
      pid = posix.getpid("pid"); -- Not caching in self, may fork.
      time_start = self.time_start_;
      time_now = now;
      uptime = now - self.time_start_;
      gc_count = collectgarbage("count");
      requests_total = self.requests_total_;
      requests_fails = self.requests_fails_;
      time_in_requests = self.time_in_requests_;
      time_idle = (now - self.time_start_) - self.time_in_requests_;
      time_per_request_rolling_avg = self.time_per_request_rolling_avg_;
      time_per_request_max = self.time_per_request_max_;
      time_per_request_min = self.time_per_request_min_;
    }
  end

  make_request_manager = function(
      request_handler,
      config_manager_maker,
      service_name
    )

    config_manager_maker = config_manager_maker or make_default_config_manager
    service_name = service_name or "(unknown)"

    arguments(
        "table", request_handler,
        "function", config_manager_maker,
        "string", service_name
      )

    return
    {
       -- TODO: Why this suddenly became a public function?
      get_context = get_context;
      --
      handle_request = handle_request;
      extend_context = extend_context;
      get_context_extension = get_context_extension;
      get_service_info = get_service_info;
      --
      request_handler_ = request_handler;
      common_context_mt_ = nil;
      config_manager_maker_ = config_manager_maker;
      --
      service_name_ = service_name;
      --
      requests_total_ = 0;
      requests_fails_ = 0;
      time_start_ = socket.gettime();
      time_in_requests_ = 0;
      time_per_request_rolling_avg_ = 0;
      time_per_request_max_ = -1;
      time_per_request_min_ = math.huge;
    }
  end
end

local make_request_manager_using_handlers
do
  local handle_request = function(self, context)
    method_arguments(
        self,
        "table", context
      )

    local handler = (self.handlers_[context.wsapi_env.PATH_INFO] or handler_404)
    return handler(context)
  end

  local make_request_handler = function(handlers)
    arguments(
        "table", handlers
      )

    return
    {
      handle_request = handle_request;
      --
      handlers_ = handlers;
    }
  end

  make_request_manager_using_handlers = function(
      handlers,
      config_manager_maker,
      service_name
    )
    arguments(
        "table", handlers
      )
    optional_arguments(
        "function", config_manager_maker,
        "string", service_name
      )

    return make_request_manager(
        make_request_handler(handlers),
        config_manager_maker,
        service_name
      )
  end
end

--------------------------------------------------------------------------------

return
{
  make_request_manager_using_handlers = make_request_manager_using_handlers;

  -- TODO: Only for backward compatibility with hospital
  handler_404 = handler_404;
  make_filesystem_request_handler = make_filesystem_request_handler;
  make_request_manager = make_request_manager;
}
