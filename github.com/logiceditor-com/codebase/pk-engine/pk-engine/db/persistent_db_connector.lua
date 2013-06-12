--------------------------------------------------------------------------------
-- persistent_db_connector.lua: persistent connector for luasql.mysql
-- This file is a part of pk-engine library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------

require 'luasql.mysql'

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

local assert_is_table
      = import 'lua-nucleo/typeassert.lua'
      {
        'assert_is_table'
      }

local make_loggers
      = import 'pk-core/log.lua'
      {
        'make_loggers'
      }

--------------------------------------------------------------------------------

local log, dbg, spam, log_error = make_loggers(
    "db/persistent_db_connector", "PDC"
  )

--------------------------------------------------------------------------------

local get_shared_db_env
do
  local shared_env = nil

  get_shared_db_env = function()
    shared_env = shared_env or luasql.mysql()

    return shared_env
  end
end

local make_db_connector
do
  local connect = function(self)
    method_arguments(self)

    local db_info = self.db_info_

    dbg("creating db connection to", db_info.db_name, db_info.address)

    local address = db_info.address
    assert_is_table(address) -- TODO: Support UDS addresses.

    return get_shared_db_env():connect(
        db_info.db_name,
        db_info.login,
        db_info.password,
        address.host,
        address.port
      )
  end

  make_db_connector = function(db_info)
    arguments(
        "table", db_info
      )

    return
    {
      connect = connect;
      --
      db_info_ = db_info;
    }
  end
end

-- TODO: Test persistence!
-- TODO: Generalize with make_persistent_connection!
local make_persistent_db_connection
do
  local connection_was_broken = function(err)
    -- TODO: ?! Too much implementation detail?
    --       Look for API to check this
    --       (or ask luasql developers to provide one if possible).
    return
      err == "LuaSQL: error executing query. MySQL: MySQL server has gone away"
  end

  -- Private method
  local get_connection = function(self)
    method_arguments(
        self
      )

    if not self.conn_proxy_ then
      local err
      self.conn_proxy_, err = self.connector_:connect()

      if not self.conn_proxy_ then
        dbg("connection failed", err)
        return nil, err
      end

      spam("connected")
    end

    return self.conn_proxy_
  end

  -- Private method
  local close_connection = function(self)
    method_arguments(
        self
      )

    if self.conn_proxy_ then
      spam("close")

      local res, err = self.conn_proxy_:close()

      self.conn_proxy_ = nil

      return res, err
    end

    return true
  end

  -- Private method
  -- TODO: Use this in persistent_connection.
  local reset_on_fail = function(self, res, ...)
    if not res then
      local err = (...)

      if connection_was_broken(err) then
        close_connection(self) -- Ignoring result
      end

      return res, err -- Preserving res value (may be false)
    end

    return res, ...
  end

  local close = function(self)
    return close_connection(self)
  end

  local delegated_method = function(name)
    return function(self, ...)
      local db_conn, err = get_connection(self)
      if not db_conn then
        log_error(name, "failed:", err)
        return nil, err
      end

      return reset_on_fail(self, db_conn[name](db_conn, ...))
    end
  end

  local refresh = function(self)
    method_arguments(
        self
      )

    local conn, err = get_connection(self)
    if not conn then
      log_error("get_connection failed:", err)
      return nil, err
    end

    return true
  end

  local commit = delegated_method("commit")

  local execute = delegated_method("execute")

  local rollback = delegated_method("rollback")

  local setautocommit = delegated_method("setautocommit")

  local escape = delegated_method("escape")

  local getlastautoid = delegated_method("getlastautoid")

  -- Add more as needed

  make_persistent_db_connection = function(db_connector)
    arguments(
        "table", db_connector
      )

    return
    {
      close = close;
      commit = commit;
      execute = execute;
      rollback = rollback;
      setautocommit = setautocommit;
      escape = escape;
      getlastautoid = getlastautoid;
      --
      refresh = refresh;
      --
      connector_ = db_connector;
      conn_proxy_ = nil;
    }
  end
end

local make_persistent_db_connector
do
  local connect = function(self)
    method_arguments(self)

    return make_persistent_db_connection(self.db_connector_)
  end

  make_persistent_db_connector = function(db_connector)
    arguments(
        "table", db_connector
      )

    return
    {
      connect = connect;
      --
      db_connector_ = db_connector;
    }
  end
end

return
{
  make_persistent_db_connector = make_persistent_db_connector;
  make_db_connector = make_db_connector; -- TODO: Move this to a separate file!
}
