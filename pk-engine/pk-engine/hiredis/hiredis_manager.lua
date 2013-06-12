--------------------------------------------------------------------------------
-- hiredis_manager.lua: hiredis manager
-- This file is a part of pk-engine library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------

local hiredis = require 'hiredis'

--------------------------------------------------------------------------------

local log, dbg, spam, log_error
      = import 'pk-core/log.lua' { 'make_loggers' } (
          "pk-engine/hiredis_manager", "HRM"
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

local tstr
      = import 'lua-nucleo/tstr.lua'
      {
        'tstr'
      }

local tset
      = import 'lua-nucleo/table-utils.lua'
      {
        'tset'
      }

local make_generic_connection_manager
      = import 'pk-engine/generic_connection_manager.lua'
      {
        'make_generic_connection_manager'
      }

--------------------------------------------------------------------------------

local make_hiredis_connection_manager
do
  local make_persistent_connection
  do
    local blocking_commands = tset
    {
      "BLPOP";
      "BRPOP";
      "BRPOPLPUSH";
    }

    local banned = setmetatable(
        { },
        {
          __index = function(t, k)
            k = k:upper()

            local v = not not (k == "SELECT" or k:find("^SELECT%s"))
            t[k] = v
            return v
          end;
        }
      )

    -- Private method
    local get_connection = function(self)
      method_arguments(self)

      if self.conn_ then
        return self.conn_
      end

      local err, err_id
      self.conn_, err, err_id = self.connector_:connect()

      if not self.conn_ then
        log_error("connection failed:", err, err_id)
        return nil, err, err_id
      end

      return self.conn_
    end

    -- Private method
    local close_connection = function(self)
      if self.conn_ then
        self.conn_:close()
        self.conn_ = nil
        log("close_connection: closed:", self.connector_:describe())
      else
        log("close_connection: already closed for:", self.connector_:describe())
      end
    end

    local command = function(self, cmd, ...)
      self.buf_ = { }

      if banned[cmd] then
        -- Have to ban SELECT, or the reconnection logic will go bad.
        -- SELECT will also break api_context:hiredis():<db_name>() stuff,
        -- so we do not really want to support it here anyway.

        log_error(debug.traceback("command: banned command detected"))
        return nil, "hiredis command " .. tostring(cmd) .. " is banned"
      end

      local conn, err, err_id = get_connection(self)
      if not conn then
        log_error("get_connection failed:", err, err_id)
        return nil, err, err_id
      end

      local time_start = socket.gettime()

      local res, err, err_id = conn:command(cmd, ...)

      -- TODO: Make limit configurable
      local time_end = socket.gettime()
      if time_end - time_start > 0.3 and not blocking_commands[cmd] then
        log_error(
            "WARNING: slow hiredis command",
            ("%04.2fs:"):format(time_end - time_start),
            self.connector_:describe(),
            cmd, ...
          )
      end

      if res == nil then
        -- In current lua-hiredis implementation all 'nil, err' errors
        -- are to be resolved by reconnection.
        -- TODO: Fragile?
        log_error("command failed:", err, err_id)
        close_connection(self)
        return nil, err, err_id
      end

      return res
    end

    -- Note that, unlike its raw hiredis counterpart,
    -- this function may return an error.
    local append_command = function(self, cmd, ...)
      if banned[cmd] then
        -- Have to ban SELECT, or the reconnection logic will go bad.
        -- SELECT will also break api_context:hiredis():<db_name>() stuff,
        -- so we do not really want to support it here anyway.

        log_error(debug.traceback("append_command: banned command detected"))
        return nil, "hiredis command " .. tostring(cmd) .. " is banned"
      end

      local conn, err, err_id = get_connection(self)
      if not conn then
        log_error("get_connection failed:", err, err_id)
        return nil, err, err_id
      end

      self.buf_[#self.buf_ + 1] = { cmd, ... }

      conn:append_command(cmd, ...) -- Does not return any meaningful value

      return true
    end

    local get_reply = function(self)
      local buf = table.remove(self.buf_, 1)

      local conn, err, err_id = get_connection(self)
      if not conn then
        log_error("get_connection failed:", err, err_id)
        return nil, err, err_id
      end

      local time_start = socket.gettime()

      local res, err, err_id = conn:get_reply()

      -- TODO: Make limit configurable
      local time_end = socket.gettime()
      if time_end - time_start > 0.3 then
        log_error(
            "WARNING: slow hiredis get_reply",
            self.connector_:describe(),
            ("%04.2fs"):format(time_end - time_start),
            buf, "buffered:", self.buf_
          )
      end

      if res == nil then
        -- In current lua-hiredis implementation all 'nil, err' errors
        -- are to be resolved by reconnection.
        -- TODO: Fragile?
        log_error("command failed:", err, err_id)
        close_connection(self)
        return nil, err, err_id
      end

      return res
    end

    local close = function(self)
      close_connection(self)
    end

    local refresh = function(self)
      local conn, err, err_id = get_connection(self)
      if not conn then
        log_error("get_connection failed:", err, err_id)
        return nil, err, err_id
      end
    end

    make_persistent_connection = function(connector)
      arguments(
          "table", connector
        )

      -- TODO: Proxy __tostring as well
      return
      {
        command = command;
        append_command = append_command;
        get_reply = get_reply;
        close = close;
        refresh = refresh;
        --
        connector_ = connector;
        conn_ = nil;
        --
        -- TODO: Overhead. Needed for slow append_command/get_reply debugging.
        buf_ = { };
      }
    end
  end

  local make_connector
  do
    local connect = function(self)
      method_arguments(self)

      local info = self.info_

      local conn, err = hiredis.connect(info.address.host, info.address.port)
      if not conn then
        log_error(
            "hiredis: failed to connect to", info.address.host, info.address.port,
            err
          )
        return nil, err
      end

      local res, err = conn:command("SELECT", info.database)
      if not res then
        log_error("hiredis: failed to select database", info.database, err)
        conn:close()
        conn = nil
        return nil, err
      end

      local res_unwrapped, err = hiredis.unwrap_reply(res)
      if res_unwrapped == nil then
        log_error("hiredis: server error on SELECT ", info.database, err)
        conn:close()
        conn = nil
        return nil, err
      end

      if res ~= hiredis.OK then
        -- TODO: ?!
        dbg("hiredis: weird SELECT result:", res)
      end

      log("hiredis: connected to", info)

      return conn
    end

    local describe = function(self)
      return "hiredis connector " .. tstr(self.info_)
    end

    make_connector = function(info)

      return
      {
        connect = connect;
        describe = describe;
        --
        info_ = info;
      }
    end
  end

  local make_persistent_connector
  do
    local connect = function(self)
      method_arguments(self)

      return make_persistent_connection(self.connector_)
    end

    local describe = function(self)
      return "persistent "
        .. (self.connector_.describe
            and self.connector_:describe()
             or "(unknown)"
          )
    end

    make_persistent_connector = function(connector)
      arguments(
          "table", connector
        )

      return
      {
        connect = connect;
        describe = describe;
        --
        connector_ = connector;
      }
    end
  end

  local create_persistent_connector = function(info)
    return make_persistent_connector(
        make_connector(info)
      )
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

  make_hiredis_connection_manager = function()
    return make_generic_connection_manager(
        create_persistent_connector,
        get_info_hash
      )
  end
end

--------------------------------------------------------------------------------

local make_hiredis_manager
do
  local acquire_hiredis_connection = function(self, hiredis_name)
    method_arguments(
        self,
        "string", hiredis_name
      )

    -- Note we're working with *redis* node info, not *hi*redis.
    local hiredis_info, err = self.config_manager_:get_redis_node_info(
        hiredis_name
      )
    if not hiredis_info then
      log_error(
          "acquire_hiredis_connection failed to resolve hiredis_name",
          hiredis_name, ":", err
        )
      return nil, err
    end

    return self.hiredis_connection_manager_:acquire(hiredis_info)
  end

  local unacquire_hiredis_connection = function(self, hiredis_conn, pool_id)
    method_arguments(
        self,
        "userdata", hiredis_conn,
        "string", pool_id
      )

    return self.hiredis_connection_manager_:unacquire(hiredis_conn, pool_id)
  end

  make_hiredis_manager = function(config_manager, hiredis_connection_manager)
    arguments(
        "table", config_manager,
        "table", hiredis_connection_manager
      )

    return
    {
      acquire_hiredis_connection = acquire_hiredis_connection;
      unacquire_hiredis_connection = unacquire_hiredis_connection;
      --
      config_manager_ = config_manager;
      hiredis_connection_manager_ = hiredis_connection_manager;
    }
  end
end

--------------------------------------------------------------------------------

return
{
  make_hiredis_connection_manager = make_hiredis_connection_manager;
  make_hiredis_manager = make_hiredis_manager;
}
