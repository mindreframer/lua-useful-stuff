--------------------------------------------------------------------------------
-- api_hiredis.lua: hiredis wrapper for api
-- This file is a part of pk-engine library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------
--
-- WARNING: To be used inside call().
--
-- TODO: Prevent calling make_api_hiredis_mt() and
--       make_hiredis_databases_mt() each time when creating api_hiredis
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
    "webservice/client_api/api_hiredis", "AHI"
  )

--------------------------------------------------------------------------------

local make_api_hiredis, destroy_api_hiredis
do
  local hiredis_manager_key = unique_object()
  local connections_cache_key = unique_object()
  local factories_cache_key = unique_object()

  local connections_mt =
  {
    __index = function(t, hiredis_name)
      local hiredis_conn, conn_id = try(
          "INTERNAL_ERROR",
          t[hiredis_manager_key]:acquire_hiredis_connection(hiredis_name)
        )

      local v = { hiredis_conn = hiredis_conn, conn_id = conn_id }
      t[hiredis_name] = v
      return v
    end
  }

  local factories_mt =
  {
    __index = function(t, hiredis_name)
      local v = function(self) -- TODO: Weird.
        return self[connections_cache_key][hiredis_name].hiredis_conn
      end
      t[hiredis_name] = v
      return v
    end;
  }

  local make_api_hiredis_mt = function() -- TODO: do we need this indirection?

    return
    {
      __index = function(self, hiredis_name)
        method_arguments(
            self,
            "string", hiredis_name
          )

        local v = self[factories_cache_key][hiredis_name]
        self[hiredis_name] = v
        return v
      end;
    }
  end

  -- A out-of-class method to allow databases named "destroy"
  destroy_api_hiredis = function(self)
    method_arguments(self)

    local connections = self[connections_cache_key]
    local hiredis_manager = connections[hiredis_manager_key]

    for hiredis_name, info in pairs(connections) do
      if hiredis_name ~= hiredis_manager_key then -- Hack
        hiredis_manager:unacquire_hiredis_connection(
            info.hiredis_conn,
            info.conn_id
          )
        connections[hiredis_name] = nil
      end
    end
  end

  make_api_hiredis = function(hiredis_manager)
    arguments(
        "table", hiredis_manager
      )

    return setmetatable(
        {
          [factories_cache_key] = setmetatable({ }, factories_mt);
          [connections_cache_key] = setmetatable(
              {
                [hiredis_manager_key] = hiredis_manager;
              },
              connections_mt
            );
        },
        make_api_hiredis_mt()
      )
  end
end

--------------------------------------------------------------------------------

return
{
  destroy_api_hiredis = destroy_api_hiredis;
  make_api_hiredis = make_api_hiredis;
}
