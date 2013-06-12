--------------------------------------------------------------------------------
-- redis_manager.lua: redis manager
-- This file is a part of pk-engine library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------

local sidereal = require 'sidereal'
local socket = require 'socket'

--------------------------------------------------------------------------------

local log, dbg, spam, log_error
      = import 'pk-core/log.lua' { 'make_loggers' } (
          "pk-engine/redis_manager", "RMA"
        )

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

local assert_is_table,
      assert_is_string,
      assert_is_number
      = import 'lua-nucleo/typeassert.lua'
      {
        'assert_is_table',
        'assert_is_string',
        'assert_is_number'
      }

local is_function
      = import 'lua-nucleo/type.lua'
      {
        'is_function'
      }

local make_generic_connection_manager
      = import 'pk-engine/generic_connection_manager.lua'
      {
        'make_generic_connection_manager'
      }

--------------------------------------------------------------------------------

-- TODO: Generalize?
local make_slowlog_proxy
do
  local maybe_log = function(time_start, time_limit, msg, ...)
    local time_passed = socket.gettime() - time_start
    if time_passed > time_limit then
      log_error((msg):format(time_passed))
    end
    return ...
  end

  make_slowlog_proxy = function(name, obj, time_limit)
    return setmetatable(
        { },
        {
          -- TODO: Proxy __tostring?
          __metatable = "slowlogger:"..name;

          __index = function(t, k)
            local v = obj[k]
            if not is_function(v) then
              return v
            end

            local fn = v

            -- TODO: This is not enough. Need to print arguments.
            local msg = "WARNING: slow "
              .. name .. " %04.2fs: " .. tostring(k)

            v = function(self, ...)
              return maybe_log(
                  socket.gettime(),
                  time_limit,
                  msg,
                  fn(self == t and obj or self, ...)
                )
            end

            t[k] = v

            return v
          end;

          __newindex = function(t, k, v)
            obj[k] = v
          end;
        }
      )
  end
end

--------------------------------------------------------------------------------

local make_redis_connection_manager
do
  -- Note that sidereal connections are already persistent.
  local create_persistent_connector
  do
    local connect = function(self)
      method_arguments(self)

      local info = self.info_

      local conn, err = sidereal.connect(info.address.host, info.address.port)
      if not conn then
        log_error(
            "redis: failed to connect to", info.address.host, info.address.port,
            err
          )
        return nil, err
      end

      local res, err = conn:select(info.database)
      if not res then
        log_error("redis: failed to select database", info.database, err)
        return nil, err
      end

      return conn

      -- TODO: Fix this ASAP
      --[[
      return make_slowlog_proxy(
          "sidereal " .. info.address.host .. ":" .. info.address.port
          .. " db " .. info.database,
          conn, 1 -- TODO: Make limit configurable
        )
      --]]
    end

    create_persistent_connector = function(info)

      return
      {
        connect = connect;
        --
        info_ = info;
      }
    end
  end

  local get_info_hash = function(info)
    arguments(
        "table", info
      )

    local address = assert_is_table(info.address)

    return "tcp:" .. assert_is_string(address.host)
      .. ":" .. assert_is_number(address.port)
      .. ";db:" .. assert_is_number(info.database)
  end

  make_redis_connection_manager = function()
    return make_generic_connection_manager(
        create_persistent_connector,
        get_info_hash
      )
  end
end

--------------------------------------------------------------------------------

local make_redis_manager
do
  local acquire_redis_connection = function(self, redis_name)
    method_arguments(
        self,
        "string", redis_name
      )

    local redis_info, err = self.config_manager_:get_redis_node_info(redis_name)
    if not redis_info then
      log_error(
          "acquire_redis_connection failed to resolve redis_name",
          redis_name, ":", err
        )
      return nil, err
    end

    return self.redis_connection_manager_:acquire(redis_info)
  end

  local unacquire_redis_connection = function(self, redis_conn, pool_id)
    method_arguments(
        self,
        "userdata", redis_conn,
        "string", pool_id
      )

    return self.redis_connection_manager_:unacquire(redis_conn, pool_id)
  end

  make_redis_manager = function(config_manager, redis_connection_manager)
    arguments(
        "table", config_manager,
        "table", redis_connection_manager
      )

    return
    {
      acquire_redis_connection = acquire_redis_connection;
      unacquire_redis_connection = unacquire_redis_connection;
      --
      config_manager_ = config_manager;
      redis_connection_manager_ = redis_connection_manager;
    }
  end
end

--------------------------------------------------------------------------------

return
{
  make_redis_connection_manager = make_redis_connection_manager;
  make_redis_manager = make_redis_manager;
}
