--------------------------------------------------------------------------------
-- check.lua: webservice-specific argument checkers for generated handlers
-- This file is a part of pk-engine library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------
--
-- NOTE: These checkers do type conversions.
-- TODO: Pick a better name.
--       A thing can't be named "checker" and do conversions at the same time.
--       Also, behaviour is too specialized for such generic name.
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

local is_string,
      is_table
      = import 'lua-nucleo/type.lua'
      {
        'is_string',
        'is_table'
      }

local make_loggers
      = import 'pk-core/log.lua'
      {
        'make_loggers'
      }

local fail
      = import 'pk-core/error.lua'
      {
        'fail'
      }

--------------------------------------------------------------------------------

local log, dbg, spam, log_error = make_loggers("webservice/client_api/check", "WCH")

--------------------------------------------------------------------------------

local check_number = function(t, is_optional, tag, field)
  local value = t[field]

  if (value == nil) and is_optional then return nil end
  if (value == "") and is_optional then return nil end

  if value == nil then
    fail(
        "BAD_INPUT",
        "missing " .. tag .. " " .. field
      )
  end

  value = tonumber(value)
  if value ~= nil then
    return value
  end

  fail(
      "BAD_INPUT",
      tag .. " " .. field .. " is not a number"
    )
end

local check_integer = function(t, is_optional, tag, field)
  local value = check_number(t, is_optional, tag, field)

  if (value == nil) and is_optional then return nil end

  if value % 1 == 0 then
    return value
  end

  fail(
      "BAD_INPUT",
      tag .. " " .. field .. " is not an integer"
    )
end

local check_nonnegative_integer = function(t, is_optional, tag, field)
  local value = check_integer(t, is_optional, tag, field)

  if (value == nil) and is_optional then return nil end

  if value >= 0 then
    return value
  end

  fail(
      "BAD_INPUT",
      tag .. " " .. field .. " is not a non-negative integer"
    )
end

local check_positive_integer = function(t, is_optional, tag, field)
  local value = check_integer(t, is_optional, tag, field)

  if (value == nil) and is_optional then return nil end

  if value >= 0 then
    return value
  end

  fail(
      "BAD_INPUT",
      tag .. " " .. field .. " is not a positive integer"
    )
end

--------------------------------------------------------------------------------

local check_text = function(t, is_optional, tag, field)
  local value = t[field]

  if (value == nil) and is_optional then return nil end
  if (value == "") and is_optional then return nil end

  if is_string(value) then
    return value
  end

  if value == nil then
    fail(
        "BAD_INPUT",
        "missing " .. tag .. " " .. field
      )
  end

  fail(
      "BAD_INPUT",
      "unexpected " .. tag .. " " .. field .. " type: `" .. type(value) .. "'"
    )
end

local check_string = function(t, is_optional, tag, field, min_length, max_length)
  local value = check_text(t, is_optional, tag, field)

  if (value == nil) and is_optional then return nil end

  local len = #value
  if len >= min_length then
    if len <= max_length then
      return value
    end

    fail(
        "BAD_INPUT",
        tag .. " " .. field .. " too long"
      )
  end

  fail(
      "BAD_INPUT",
      tag .. " " .. field .. " too short"
    )
end

-- Intentionally not checking that string has hex characters only,
-- that would be too slow. Check separately if needed.
local check_uuid = function(t, is_optional, tag, field)
  local value = check_text(t, is_optional, tag, field)

  if (value == nil) and is_optional then return nil end

  if #value == 36 then
    return value
  end

  fail(
      "BAD_INPUT",
      tag .. " " .. field .. " is not UUID"
    )
end

-- TODO: this is new file check, subject to test
local check_file = function(t, is_optional, tag, field)

  local value = t["file"]

  if (value == nil or value == "") and is_optional then
    return nil
  end

  if is_table(value) then
    return value
  end

  if value == nil then
    fail(
        "BAD_INPUT",
        "missing " .. tag .. " " .. field
      )
  end

  fail(
      "BAD_INPUT",
      "unexpected " .. tag .. " " .. field .. " type: `" .. type(value) .. "'"
    )
end

--------------------------------------------------------------------------------

local check_db_id = check_positive_integer

--------------------------------------------------------------------------------

local check_int_enum = function(t, is_optional, tag, field, values_set)
  local value = check_integer(t, is_optional, tag, field)

  if (value == nil) and is_optional then return nil end

  if values_set[value] then
    return value
  end

  if value == nil then
    if is_optional then return nil end
    fail(
        "BAD_INPUT",
        "missing " .. tag .. " " .. field
      )
  end

  fail(
      "BAD_INPUT",
      "unknown " .. tag .. " " .. field .. ": " .. tostring(value)
    )
end

local check_string_enum = function(t, is_optional, tag, field, values_set)
  -- TODO: must be check_string. Get minimum and maximum length from values_set.
  local value = check_text(t, is_optional, tag, field)

  if (value == nil) and is_optional then return nil end

  if values_set[value] then
    return value
  end

  if value == nil then
    if is_optional then return nil end
    fail(
        "BAD_INPUT",
        "missing " .. tag .. " " .. field
      )
  end

  fail(
      "BAD_INPUT",
      "unknown " .. tag .. " " .. field .. ": " .. tostring(value)
    )
end

--------------------------------------------------------------------------------

local check_ilist_item
do
  local check_ilist_item_field = function(
      t, field_data, prefix, ilist_tag, ilist_field, index
    )
    local checkers =
    {
      number = check_number;
      integer = check_integer;
      nonnegative_integer = check_nonnegative_integer;
      positive_integer = check_positive_integer;
      --
      text = check_text;
      string = check_string;
      uuid = check_uuid;
      --
      db_id = check_db_id;
      file = check_file;
      --
      int_enum = check_int_enum;
      string_enum = check_string_enum;
      --
      -- Note: 'ilist' is not allowed here
    }

    local checker = checkers[field_data.checker]
    if not checker then
      fail(
          "BAD_INPUT",
          ilist_tag .. " " .. ilist_field .. " field " .. tostring(index)
        .. " has invalid checker: `" .. tostring(field_data.checker) .. "'"
        )
    end

    local field = prefix .. "[" .. field_data.field .. "]"

    return checker(
        t, field_data.is_optional, field_data.tag, field,
        unpack(field_data)
      )
  end

  check_ilist_item = function(t, index, ilist_tag, ilist_field, fields)
    local prefix = ilist_field .. "[" .. tostring(index) .. "]"
    local item = {}

    for k, field_data in pairs(fields) do
      item[k] = check_ilist_item_field(
          t, field_data, prefix, ilist_tag, ilist_field, index
        )
    end

    return item;
  end
end

local check_ilist = function(t, is_optional, tag, field, fields)
  local size = check_integer(t, is_optional, tag, field .. "[size]")

  if size == nil then
    if is_optional then return nil end
    fail(
        "BAD_INPUT",
        tag .. " " .. field .. " has no size"
      )
  end

  local result = {}

  for i = 1, size do
     local item = check_ilist_item(t, i, tag, field, fields)
     if not item then
      fail(
          "BAD_INPUT",
          tag .. " " .. field .. " has no item " .. tostring(i)
        )
     end
     result[#result + 1] = item
  end

  return result
end

--------------------------------------------------------------------------------

return -- Note renames
{
  number = check_number;
  integer = check_integer;
  nonnegative_integer = check_nonnegative_integer;
  positive_integer = check_positive_integer;
  --
  text = check_text;
  string = check_string;
  uuid = check_uuid;
  --
  db_id = check_db_id;
  file = check_file;
  --
  int_enum = check_int_enum;
  string_enum = check_string_enum;
  --
  ilist = check_ilist;
}
