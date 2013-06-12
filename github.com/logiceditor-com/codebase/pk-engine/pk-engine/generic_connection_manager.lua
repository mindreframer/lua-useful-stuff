--------------------------------------------------------------------------------
-- generic_connection_manager.lua
-- This file is a part of pk-engine library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
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

local is_table,
      is_string
      = import 'lua-nucleo/type.lua'
      {
        'is_table',
        'is_string'
      }

local connect,
      make_tcp_connector,
      make_domain_socket_connector
      = import 'pk-engine/connector.lua'
      {
        'connect',
        'make_tcp_connector',
        'make_domain_socket_connector'
      }

local make_connection_pool
      = import 'pk-engine/connection_pool.lua'
      {
        'make_connection_pool'
      }

local make_loggers
      = import 'pk-core/log.lua'
      {
        'make_loggers'
      }

--------------------------------------------------------------------------------

local log, dbg, spam, log_error = make_loggers("generic_connection_manager", "GCM")

--------------------------------------------------------------------------------

local make_generic_connection_manager
do
  local acquire = function(self, info)
    method_arguments(
        self
      )
    assert(is_table(info) or is_string(info))

    local pool_id = assert(self.info_hasher_(info))
    local pool = self.pools_[pool_id]
    if not pool then
      pool = make_connection_pool(
          assert(self.connector_maker_(info))
        )
      self.pools_[pool_id] = pool

      -- Not logging info -- it may contain password.
      spam("created connection pool", pool_id) --, info)
    end

    -- spam("acquiring connection from pool", pool_id)

    local conn, err = pool:acquire()
    if not conn then
      log_error("acquire failed:", err)
      return nil, err
    end

    return conn, pool_id
  end

  local unacquire = function(self, conn, pool_id)
    method_arguments(
        self,
        "userdata", conn,
        "string", pool_id
      )

    local pool = assert(self.pools_[pool_id])

    -- spam("unacquiring connection from pool", pool_id)

    pool:unacquire(conn)
  end

  make_generic_connection_manager = function(connector_maker, info_hasher)
    arguments(
        "function", connector_maker,
        "function", info_hasher
      )

    return
    {
      acquire = acquire;
      unacquire = unacquire;
      --
      connector_maker_ = connector_maker;
      info_hasher_ = info_hasher;
      --
      pools_ = { };
    }
  end
end

return
{
  make_generic_connection_manager = make_generic_connection_manager;
}
