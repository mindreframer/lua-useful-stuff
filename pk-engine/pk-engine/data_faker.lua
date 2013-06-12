--------------------------------------------------------------------------------
-- data_faker.lua: fake data generator
-- This file is a part of pk-engine library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------
--
-- Inspired by Ruby class.
--
-- TODO: Move to lua-aplicado (thus, no logging initialization here)
--
--------------------------------------------------------------------------------

local uuid = require 'uuid'
local md5 = require 'md5'

local md5_sumhexa = md5.sumhexa

--------------------------------------------------------------------------------

local arguments,
      optional_arguments,
      method_arguments
      = import 'lua-nucleo/args.lua'
      {
        'arguments',
        'optional_arguments',
        'method_arguments',
      }

local assert_is_number
      = import 'lua-nucleo/typeassert.lua'
      {
        'assert_is_number'
      }

local tserialize,
      tvalues,
      tgenerate_n
      = import 'lua-nucleo/table.lua'
      {
        'tserialize',
        'tvalues',
        'tgenerate_n'
      }

local get_day_timestamp
      = import 'lua-nucleo/timestamp.lua'
      {
        'get_day_timestamp'
      }

local FAKE_UUIDS = import 'pk-engine/fake_uuids.lua' ()

--------------------------------------------------------------------------------

-- TODO: Move to lua-aplicado
local make_data_faker
do
  local CHARS
  do
    CHARS =
    {
      " ", "-", "_"
    }

    for c = ('a'):byte(), ('z'):byte() do
      CHARS[#CHARS + 1] = string.char(c)
    end

    for c = ('A'):byte(), ('Z'):byte() do
      CHARS[#CHARS + 1] = string.char(c)
    end

    for c = ('0'):byte(), ('9'):byte() do
      CHARS[#CHARS + 1] = string.char(c)
    end
  end

  local rand_char = function()
    return CHARS[math.random(#CHARS)]
  end

  -- TODO: Arbitrary limits
  local INT_MIN, INT_MAX = -1e5, 1e5
  local TIME = 1267405616

  -- TODO: WTF?! Not generic at all! Should return boolean, not number!
  local boolean = function(self)
    method_arguments(self)

    return math.random(0, 1)
  end

  local counter = function(self)
    method_arguments(self)

    return math.random(0, INT_MAX)
  end

  local int = function(self)
    method_arguments(self)

    return math.random(INT_MIN, INT_MAX)
  end

  local ip = function(self)
    method_arguments(self)

    -- TODO: Pick some more realistic values.
    return math.random(1, 255)
      .. "." .. math.random(1, 255)
      .. "." .. math.random(1, 255)
  end

  local md5 = function(self)
    method_arguments(self)

    return md5_sumhexa("salt" .. tostring(math.random()))
  end

  local password = function(self)
    method_arguments(self)

    return md5_sumhexa("salt" .. tostring(math.random()))
  end

  local optional_ip = function(self)
    method_arguments(self)

    local choice = math.random(1, 2)
    if choice == 1 then
      return ""
    end

    return self:ip()
  end

  local optional_ref = function(self)
    method_arguments(self)

    local choice = math.random(1, 2)
    if choice == 1 then
      return 0
    end

    return self:ref()
  end

  local ref = function(self)
    method_arguments(self)

    return math.random(0, INT_MAX)
  end

  local primary_key = function(self)
    method_arguments(self)

    return math.random(0, INT_MAX)
  end

  local primary_ref = function(self)
    method_arguments(self)

    return math.random(0, INT_MAX)
  end

  local text = function(self)
    method_arguments(self)

    -- TODO: Should include newlines
    return self:string(65535)
  end

  local timeofday = function(self)
    method_arguments(self)

    return math.random(0, 60 * 60 * 24 - 1)
  end

  local timestamp = function(self)
    method_arguments(self)

    return math.random(0, INT_MAX)
  end

  -- Recent existing timestamp
  local timestamp_created = function(self)
    method_arguments(self)

    return TIME - math.random(0, 1000)
  end

  local day_timestamp = function(self)
    method_arguments(self)

    return get_day_timestamp(math.random(0, TIME))
  end

  local uuid = function(self)
    method_arguments(self)

    -- Have to use pre-generated uuids since luuid can't be seeded.
    return FAKE_UUIDS[math.random(#FAKE_UUIDS)]
  end

  local weekdays = function(self)
    method_arguments(self)

    return self:flags(
        {
          mo = 1;
          tu = 2;
          we = 4;
          th = 8;
          fr = 16;
          sa = 32;
          su = 64;
        }
      )
  end

  local string = function(self, max_length)
    method_arguments(
        self,
        "number", max_length
      )

    -- TODO: ?! Striving for better readability
    max_length = math.min(max_length, 60)

    return table.concat(tgenerate_n(math.random(0, max_length), rand_char), "")
  end

  local int_enum = function(self, values)
    method_arguments(
        self,
        "table", values
      )

    values = tvalues(values)
    return assert_is_number(values[math.random(#values)])
  end

  local flags = function(self, values)
    method_arguments(
        self,
        "table", values
      )

    -- TODO: Generate OR-ed flags as well!
    values = tvalues(values)
    return values[math.random(#values + 1)] or 0
  end

  -- Matches sql db schema fields.
  -- Feel free to extend.
  make_data_faker = function()

    return
    {
      boolean = boolean;
      counter = counter;
      int = int;
      ip = ip;
      md5 = md5;
      password = password;
      optional_ip = optional_ip;
      optional_ref = optional_ref;
      primary_key = primary_key;
      primary_ref = primary_ref;
      ref = ref;
      text = text;
      timeofday = timeofday;
      timestamp = timestamp;
      day_timestamp = day_timestamp;
      timestamp_created = timestamp_created;
      uuid = uuid;
      weekdays = weekdays;
      string = string;
      int_enum = int_enum;
      flags = flags;
    }
  end
end

--------------------------------------------------------------------------------

return
{
  make_data_faker = make_data_faker;
}
