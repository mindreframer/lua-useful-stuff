--------------------------------------------------------------------------------
-- object_tag_type_value.lua: webservice database handlers for object tag type values
-- This file is a part of pk-admin library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------
--
-- WARNING: To be used inside call().
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

local try,
      call,
      fail
      = import 'pk-core/error.lua'
      {
        'try',
        'call',
        'fail'
      }

local make_loggers
      = import 'pk-core/log.lua'
      {
        'make_loggers'
      }

--------------------------------------------------------------------------------

local log, dbg, spam, log_error = make_loggers("webservice/db/object_tag_type_value", "TTV")

--------------------------------------------------------------------------------

local get_enum_tag_value_name = function (object_tag_api, api_db, tag_value_id)
  local table_api = object_tag_api.get_tag_type_values_table_api(api_db)
  if not table_api then
    fail("INTERNAL_ERROR", "table not found")
  end

  local item = try("INTERNAL_ERROR", table_api:get(tag_value_id))
  if item == false then
    return "invalid enum type"
  end

  return item.name
end


local get_tag_values = function (object_tag_api, api_db, tag_type_id)
  local table_api = object_tag_api.get_tag_type_values_table_api(api_db)
  if not table_api then
    fail("INTERNAL_ERROR", "table not found")
  end

  local post_query = " AND tag_type_id='" .. tag_type_id .. "'"

  local items = try("INTERNAL_ERROR", table_api:list(post_query))

  return items
end


local delete_tag_values = function (object_tag_api, api_db, tag_type_id)
  local table_api = object_tag_api.get_tag_type_values_table_api(api_db)
  if not table_api then
    fail("INTERNAL_ERROR", "table not found")
  end

  local post_query = " AND tag_type_id='" .. tag_type_id .. "'"

  local count = try(
      "INTERNAL_ERROR",
      table_api:delete_many(object_tag_api.MAX_TAG_ENUM_VALUES_, post_query)
    )

  return count
end

--------------------------------------------------------------------------------

return
{
  get_enum_tag_value_name = get_enum_tag_value_name;
  get_tag_values = get_tag_values;
  delete_tag_values = delete_tag_values;
}
