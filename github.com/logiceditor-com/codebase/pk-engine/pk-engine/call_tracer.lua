--------------------------------------------------------------------------------
-- call_tracer.lua
-- This file is a part of pk-engine library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------

-- TODO: Port to lua-nucleo!
-- TODO: Port to use method_arguments()

local debug_traceback = debug.traceback
local table_remove, table_concat = table.remove, table.concat

local assert_is_self,
      assert_is_number
      = import 'lua-nucleo/typeassert.lua'
      {
        'assert_is_self',
        'assert_is_number'
      }

local make_call_tracer
do
  local push = function(self)
    assert_is_self(self)
    local n = self:size() + 1
    self.stack_[n] = self:snapshot()
    return n
  end

  local pop = function(self, callid)
    assert_is_self(self)
    assert_is_number(callid)

    if callid == 0 or self:size() ~= callid then
      error("bad callid "..callid..", expected "..self:size().."\n"..self:dump())
    end

    table_remove(self.stack_)
  end

  local size = function(self)
    assert_is_self(self)
    return #self.stack_
  end

  local empty = function(self)
    assert_is_self(self)
    return self:size() == 0
  end

  local snapshot = function(self)
    assert_is_self(self)

    -- TODO: SLOW! No need for whole call stack! Capture as little as possible.

    return debug_traceback()
  end

  local dump = function(self)
    assert_is_self(self)

    local str

    local n = self:size()
    if n == 0 then
      str = "(empty)"
    else
      str = {}

      for i = n, 1, -1 do
        str[#str + 1] = "-- "..i.." --\n"
        str[#str + 1] = self.stack_[i]
        str[#str + 1] = "\n"
      end

      str = table_concat(str, "")
    end

    return str
  end

  make_call_tracer = function()

    return
    {
      push = push;
      pop = pop;
      size = size;
      empty = empty;
      snapshot = snapshot;
      dump = dump;
      --
      stack_ = {};
    }
  end
end

return
{
  make_call_tracer = make_call_tracer;
}
