--------------------------------------------------------------------------------
-- api_redis.lua: redis wrapper for api
-- This file is a part of pk-engine library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------
--
-- WARNING: To be used inside call().
--
-- TODO: Prevent calling make_api_redis_mt() and
--       make_redis_databases_mt() each time when creating api_redis
--
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

local is_table
      = import 'lua-nucleo/type.lua'
      {
        'is_table'
      }

local assert_is_table
      = import 'lua-nucleo/typeassert.lua'
      {
        'assert_is_table'
      }

local unique_object
      = import 'lua-nucleo/misc.lua'
      {
        'unique_object'
      }

local make_loggers
      = import 'pk-core/log.lua'
      {
        'make_loggers'
      }

local try
      = import 'pk-core/error.lua'
      {
        'try'
      }

--------------------------------------------------------------------------------

local log, dbg, spam, log_error = make_loggers(
    "webservice/client_api/api_redis", "ARE"
  )

--------------------------------------------------------------------------------

local make_api_redis, destroy_api_redis
do
  local redis_manager_key = unique_object()
  local connections_cache_key = unique_object()
  local factories_cache_key = unique_object()

  local connections_mt =
  {
    __index = function(t, redis_name)
      local redis_conn, conn_id = try(
          "INTERNAL_ERROR",
          t[redis_manager_key]:acquire_redis_connection(redis_name)
        )

      local v = { redis_conn = redis_conn, conn_id = conn_id }
      t[redis_name] = v
      return v
    end
  }

  local factories_mt =
  {
    __index = function(t, redis_name)
      local v = function(self) -- TODO: Weird.
        return self[connections_cache_key][redis_name].redis_conn
      end
      t[redis_name] = v
      return v
    end;
  }

  local make_api_redis_mt = function() -- TODO: do we need this indirection?

    return
    {
      __index = function(self, redis_name)
        method_arguments(
            self,
            "string", redis_name
          )

        local v = self[factories_cache_key][redis_name]
        self[redis_name] = v
        return v
      end;
    }
  end

  -- A out-of-class method to allow databases named "destroy"
  destroy_api_redis = function(self)
    method_arguments(self)

    local connections = self[connections_cache_key]
    local redis_manager = connections[redis_manager_key]

    for redis_name, info in pairs(connections) do
      if redis_name ~= redis_manager_key then -- Hack
        redis_manager:unacquire_redis_connection(info.redis_conn, info.conn_id)
        connections[redis_name] = nil
      end
    end
  end

  make_api_redis = function(redis_manager)
    arguments(
        "table", redis_manager
      )

    return setmetatable(
        {
          [factories_cache_key] = setmetatable({ }, factories_mt);
          [connections_cache_key] = setmetatable(
              {
                [redis_manager_key] = redis_manager;
              },
              connections_mt
            );
        },
        make_api_redis_mt()
      )
  end
end

--------------------------------------------------------------------------------

return
{
  destroy_api_redis = destroy_api_redis;
  make_api_redis = make_api_redis;
}
