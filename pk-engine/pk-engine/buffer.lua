--------------------------------------------------------------------------------
-- buffer.lua: not very generic buffer
-- This file is a part of pk-engine library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------
--
-- TODO: Need less generic name
-- TODO: Optimizable. Do not reorder buffer on each read; do some caching.
-- TODO: Optimizable. Do not crop partially read string in buffer,
--       store some offset instead.
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

local split_by_offset
      = import 'lua-nucleo/string.lua'
      {
        'split_by_offset'
      }

local make_loggers
      = import 'pk-core/log.lua'
      {
        'make_loggers'
      }

--------------------------------------------------------------------------------

local log, dbg, spam, log_error = make_loggers("buffer", "BUF")

--------------------------------------------------------------------------------

local make_buffer
do
  local write = function(self, chunk)
    method_arguments(
        self,
        "string", chunk
      )
    self.size_ = self.size_ + #chunk
    self.data_[#self.data_ + 1] = chunk
  end

  local read = function(self, size)
    method_arguments(
        self,
        "number", size
      )

    assert(self.size_ >= size)

    if size == self.size then
      return self:read_all()
    end

    local data = self.data_

    -- Find the
    local sum_size = 0
    local num_full_parts = 0
    for i = 1, #data do
      local new_size = sum_size + #data[i]
      if new_size > size then
        break
      end

      sum_size = new_size
      num_full_parts = i
    end

    local tail = ""
    if sum_size < size then
      tail, data[num_full_parts + 1] = split_by_offset(
          data[num_full_parts + 1],
          size - sum_size
        )
    end

    local result = tail
    if num_full_parts > 0 then
      result = table.concat(data, "", 1, num_full_parts) .. result
      for i = num_full_parts, 1, -1 do
        table.remove(data, i)
      end
    end

    self.size_ = self.size_ - size

    return result
  end

  -- Returns false if no data found
  -- Filters out stop_char (it is marked as read, but not returned)
  local read_until = function(self, stop_char)
    method_arguments(
        self,
        "string", stop_char
      )

    local tail

    local data = self.data_

    local num_full_parts = 0
    for i = 1, #data do
      local offset = data[i]:find(stop_char, 1, true)
      if offset then
        tail, data[i] = split_by_offset(data[i], offset - 1, 1)
        break
      end
      num_full_parts = num_full_parts + 1
    end

    if not tail then
      return false -- Stop character not found
    end

    local result = tail
    if num_full_parts > 0 then
      result = table.concat(data, "", 1, num_full_parts) .. tail
      for i = num_full_parts, 1, -1 do
        table.remove(data, i)
      end
    end

    self.size_ = self.size_ - (#result + 1)

    return result
  end

  local read_all = function(self)
    method_arguments(
        self
      )

    local result = table.concat(self.data_)
    self.data_ = { }
    self.size_ = 0
    return result
  end

  local unread_size = function(self)
    method_arguments(
        self
      )

    return self.size_
  end

  make_buffer = function()

    return
    {
      write = write;
      read = read;
      read_until = read_until;
      read_all = read_all;
      unread_size = unread_size;
      --
      data_ = { };
      size_ = 0;
    }
  end
end

-- TODO: Move to proper test suite
--[[
do
  local buf = make_buffer()
  assert(buf:unread_size() == 0)

  buf:write("a")
  assert(buf:unread_size() == 1)
  assert(buf:read(1) == "a")
  assert(buf:unread_size() == 0)

  buf:write("abcde")
  assert(buf:unread_size() == 5)
  assert(buf:read(3) == "abc")
  assert(buf:unread_size() == 2)
  assert(buf:read(2) == "de")
  assert(buf:unread_size() == 0)

  buf:write("ab")
  buf:write("cde")
  assert(buf:unread_size() == 5)
  assert(buf:read_all() == "abcde")
  assert(buf:unread_size() == 0)

  buf:write("ab")
  buf:write("cde")
  assert(buf:unread_size() == 5)
  assert(buf:read(3) == "abc")
  assert(buf:unread_size() == 2)
  assert(buf:read(2) == "de")
  assert(buf:unread_size() == 0)

  buf:write("XXa")
  buf:write("bXc")
  assert(buf:unread_size() == 6)
  assert(buf:read_until("X") == "")
  assert(buf:unread_size() == 5)
  assert(buf:read_until("X") == "")
  assert(buf:unread_size() == 4)
  assert(buf:read_until("X") == "ab")
  assert(buf:unread_size() == 1)
  assert(buf:read_until("X") == false)
  assert(buf:unread_size() == 1)
  buf:write("X")
  assert(buf:read_until("X") == "c")
  assert(buf:unread_size() == 0)
end
--]]

--------------------------------------------------------------------------------

return
{
  make_buffer = make_buffer;
}
