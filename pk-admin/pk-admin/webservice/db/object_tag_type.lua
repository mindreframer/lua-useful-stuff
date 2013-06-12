--------------------------------------------------------------------------------
-- object_tag_type.lua: webservice database handlers for object tag types
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

local log, dbg, spam, log_error = make_loggers("webservice/db/object_tag_type", "WTT")

--------------------------------------------------------------------------------

local delete_tag_type = function (object_tag_api, api_db, tag_type_id)
  local tag_types_table_api = object_tag_api.get_tag_types_table_api(api_db)

  local found = try("INTERNAL_ERROR", tag_types_table_api:delete(tag_type_id))
  if found == false then
    return false
  end

  assert(found == true)

  try(
      "INTERNAL_ERROR",
      object_tag_api.object_tags.delete_tag(
          object_tag_api, api_db, tag_type_id
        )
    )

  try(
      "INTERNAL_ERROR",
      object_tag_api.tag_type_values.delete_tag_values(
          object_tag_api, api_db, tag_type_id
        )
    )

  return true
end


local get_tag_type_by_id = function(object_tag_api, api_db, tag_type_id)
  local tag_types_table_api = object_tag_api.get_tag_types_table_api(api_db)

  return try("INTERNAL_ERROR", tag_types_table_api:get(tag_type_id))
end

local insert_tag_type = function(object_tag_api, api_db, data)
  local tag_types_table_api = object_tag_api.get_tag_types_table_api(api_db)

  try("INTERNAL_ERROR", tag_types_table_api:insert(data))

  return try("INTERNAL_ERROR", tag_types_table_api:getlastautoid())
end

local list_tag_types = function (object_tag_api, api_db, start, limit, with_values)
  local tag_types_table_api = object_tag_api.get_tag_types_table_api(api_db)

  local post_query = " LIMIT " .. start .. "," .. limit
  local items = try("INTERNAL_ERROR", tag_types_table_api:list(post_query))

  if with_values then
    for i = 1, #items do
      local value_type = tonumber(items[i].value_type)
      if not value_type then
        fail("INTERNAL_ERROR", "tag" .. items[i].id .. "value_type is not a number")
      end

      if value_type == object_tag_api.TAG_VALUE_TYPE_.ENUM then
        local values = object_tag_api.tag_type_values.get_tag_values(
            object_tag_api, api_db, items[i].id
          )
        if values then
          items[i].values = values
        end
      end
    end
  end

  local count = try("INTERNAL_ERROR", tag_types_table_api:count())

  return items, count
end


local update_tag_type = function(object_tag_api, api_db, data)
  local tag_types_table_api = object_tag_api.get_tag_types_table_api(api_db)

  return try("INTERNAL_ERROR", tag_types_table_api:update(data))
end

--------------------------------------------------------------------------------

local get_tag_value_type = function (object_tag_api, api_db, tag_type_id)
  local tag_types_table_api = object_tag_api.get_tag_types_table_api(api_db)

  local item = try("INTERNAL_ERROR", tag_types_table_api:get(tag_type_id))

  local value_type = tonumber(item.value_type)
  if not value_type then
    fail("INTERNAL_ERROR", "value_type is not a number")
  end

  return value_type
end

--------------------------------------------------------------------------------

local get_linked_tag_type_table = function (object_tag_api, api_db, tag_type_id)
  local tag_types_table_api = object_tag_api.get_tag_types_table_api(api_db)

  local item = try("INTERNAL_ERROR", tag_types_table_api:get(tag_type_id))

  return item.linked_tag_type_table
end

local get_linked_object_table
do
  -- TODO: Hack: project-dependent thing, to be generalized
  local OBJECT_TABLE_BY_TAG_TYPE_TABLE =
  {
    ["volunteer_tag_types"] = "volunteers";
    ["task_tag_types"] = "tasks";
  }

  get_linked_object_table = function (object_tag_api, api_db, tag_type_id)
    local tag_types_table_api = object_tag_api.get_tag_types_table_api(api_db)

    local item = try("INTERNAL_ERROR", tag_types_table_api:get(tag_type_id))

    if item.linked_tag_type_table and #item.linked_tag_type_table > 0 then
      return OBJECT_TABLE_BY_TAG_TYPE_TABLE[item.linked_tag_type_table]
    end

    return nil
  end
end
--------------------------------------------------------------------------------

local get_tag_types_linked_with_table = function (
    object_tag_api, api_db, linked_tag_type_table_name,
    linked_tag_type_id, limit
  )
  local tag_types_table_api = object_tag_api.get_tag_types_table_api(api_db)

  local post_query = " AND value_type='" .. object_tag_api.TAG_VALUE_TYPE_.DB_ID .. "'"
    .. " AND linked_tag_type_table='" .. linked_tag_type_table_name .. "'"

  if linked_tag_type_id then
    post_query = post_query .. "AND linked_tag_type_id='" .. linked_tag_type_id .. "'"
  end

  local limit = limit or object_tag_api.MAX_TAG_TYPES_

  post_query = post_query .. " LIMIT 0," .. limit

  local tag_types = try("INTERNAL_ERROR", tag_types_table_api:list(post_query))

  return tag_types
end
--------------------------------------------------------------------------------

return
{
  delete = delete_tag_type;
  get_by_id = get_tag_type_by_id;
  insert = insert_tag_type;
  list = list_tag_types;
  update = update_tag_type;
  --
  get_tag_value_type = get_tag_value_type;
  get_linked_tag_type_table = get_linked_tag_type_table;
  get_linked_object_table = get_linked_object_table;
  get_tag_types_linked_with_table = get_tag_types_linked_with_table;
}
