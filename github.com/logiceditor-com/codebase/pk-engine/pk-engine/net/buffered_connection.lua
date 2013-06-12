--------------------------------------------------------------------------------
-- buffered_connection.lua: buffered connection wrapper for luasocket
-- This file is a part of pk-engine library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------
--
-- TODO: Better imitate luasocket interface (but keep additional features)
--
--------------------------------------------------------------------------------

local arguments,
      method_arguments,
      optional_arguments
      = import 'lua-nucleo/args.lua'
      {
        'arguments',
        'method_arguments',
        'optional_arguments'
      }

local make_buffer
      = import 'pk-engine/buffer.lua'
      {
        'make_buffer'
      }

local make_loggers
      = import 'pk-core/log.lua'
      {
        'make_loggers'
      }

--------------------------------------------------------------------------------

local log, dbg, spam, log_error = make_loggers("net/buffered_connection", "BUC")

--------------------------------------------------------------------------------

local make_buffered_connection
do
  local send_bytes = function(self, data, i, j)
    -- Note that send() is unbuffered
    --spam("send", i, j, data)
    return self.conn_:send(data, i, j)
  end

  -- Private method
  local receive_once = function(self)
    local buffer = self.buf_

    --spam("receiving from", self.conn_:getfd())

    local res, err, partial = self.conn_:receive("*a")
    if res then
      --spam("received once (normal)", '`'..res..'"', self.conn_:getfd())
      buffer:write(res)
    elseif
      err == "timeout" or (err == "closed" and partial ~= "")
    then
      if partial then
        --spam("received once (partial)", '`'..partial..'"', self.conn_:getfd())
        buffer:write(partial)
      end
    else
      if partial ~= "" then
        -- TODO: ?!
        --spam("received once (err)", '`'..partial..'"', self.conn_:getfd())
        buffer:write(partial) -- Writing partial data anyway
      end

      --if partial == "" then
      --  spam("receive once (err, no partial)", self.conn_:getfd())
      --end

      log_error("receive('*a') failed:", err)
      return nil, err
    end

    return true
  end

  local receive_bytes = function(self, bytes)
    method_arguments(
        self,
        "number", bytes
      )

    local buffer = self.buf_

    local buffer_size = buffer:unread_size()
    while buffer_size < bytes do
      local res, err = receive_once(self)
      if not res then
        log_error("receive_once failed:", err)
        return nil, err
      end

      buffer_size = buffer:unread_size()
    end

    return buffer:read(bytes)
  end

  local receive_until = function(self, stop_char)
    local buffer = self.buf_

    --spam("receive_until")

    local existing = buffer:read_until(stop_char)
    if existing then
      --spam("received from buffer", "`"..existing.."'")
      return existing
    end

    -- TODO: Optimizable? Try to avoid using secondary buffer.
    local read = { (buffer:read_all()) }
    local found = false
    while true do
      local res, err = receive_once(self)
      if not res then
        -- TODO: ?!
        buffer:write(table.concat(read)) -- Put all read data back into buffer

        log_error("receive_once failed:", err)
        return nil, err
      end

      found = buffer:read_until(stop_char)
      if found then
        read[#read + 1] = found
        break
      end

      -- TODO: Optimizable. No need to pass this through internal buffer!
      read[#read + 1] = buffer:read_all()
    end

    --spam("received", "`"..table.concat(read).."'")

    return table.concat(read)
  end

  local close = function(self)
    return self.conn_:close()
  end

  local getfd = function(self)
    return self.conn_:getfd()
  end

  make_buffered_connection = function(conn)
    conn:settimeout(0)

    return
    {
      send_bytes = send_bytes;
      receive_bytes = receive_bytes;
      receive_until = receive_until;
      close = close;
      getfd = getfd;
      --
      conn_ = conn;
      buf_ = make_buffer();
    }
  end
end

--------------------------------------------------------------------------------

-- TODO: Reuse with pk-engine/srv/base_conn.lua

local read_bytes = function(buf_conn, size)
  return buf_conn:receive_bytes(size)
end

local send_bytes = function(buf_conn, data)
  return buf_conn:send_bytes(data)
end

local read_const = function(buf_conn, expected)
  local data, err = read_bytes(buf_conn, #expected)

  if data == expected then
    return true
  end

  if err then
    log_error("read_bytes failed:", err)
    return nil, err
  end

  return nil, "unexpected data `"..tostring(data).."'"
end

local read_until = function(buf_conn, stop_char)
  return buf_conn:receive_until(stop_char)
end

--------------------------------------------------------------------------------

return
{
  make_buffered_connection = make_buffered_connection;
  --
  read_bytes = read_bytes;
  send_bytes = send_bytes;
  read_const = read_const;
  read_until = read_until;
}
