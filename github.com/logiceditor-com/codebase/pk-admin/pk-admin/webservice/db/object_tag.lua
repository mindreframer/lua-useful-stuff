--------------------------------------------------------------------------------
-- object_tag.lua: webservice database handlers for object tags
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

local postquery_for_data
      = import 'pk-engine/db/query.lua'
      {
        'postquery_for_data'
      }

--------------------------------------------------------------------------------

local log, dbg, spam, log_error = make_loggers("webservice/db/task_tag", "TTG")

--------------------------------------------------------------------------------

local get_obj_tag = function (object_tag_api, api_db, obj_id, tag_type_id)
  local tags_table_api = object_tag_api.get_tags_table_api(api_db)

  return try("INTERNAL_ERROR", tags_table_api:get(
      { [object_tag_api.DB_FIELD_OBJ_ID_] = obj_id; tag_type_id = tag_type_id; }
    ))
end

--------------------------------------------------------------------------------

local delete_tag_enum_value = function (object_tag_api, api_db, tag_type_id, tag_value_id)
  local value_type = object_tag_api.tag_types.get_tag_value_type(
      object_tag_api, api_db, tag_type_id
    )
  if value_type ~= object_tag_api.TAG_VALUE_TYPE_.ENUM then
    return 0
  end

  local tags_table_api = object_tag_api.get_tags_table_api(api_db)

  local post_query =
    " AND tag_type_id='" .. tag_type_id .. "' AND int_value='" .. tag_value_id .. "'"

  local count = try(
      "INTERNAL_ERROR",
      tags_table_api:delete_many(object_tag_api.MAX_OBJECTS_, post_query)
    )
  return count
end


local delete_tag_db_id_value = function (
    object_tag_api, api_db, db_id, linked_table_name, linked_tag_type_id
  )
  local tags = object_tag_api.tag_types.get_tag_types_linked_with_table(
      object_tag_api, api_db, linked_table_name, linked_tag_type_id
    )
  if not tags or #tags == 0 then
    return 0
  end

  local post_query = " AND int_value='" .. db_id .. "' AND ("

  for i = 1, #tags do
    post_query = post_query .. (i == 1 and "" or " OR ")
      .. "tag_type_id='" .. tags[i].id .. "'"
  end
  local post_query = post_query .. ")"

  local tags_table_api = object_tag_api.get_tags_table_api(api_db)

  local count = try(
      "INTERNAL_ERROR",
      tags_table_api:delete_many(object_tag_api.MAX_OBJECTS_, post_query)
    )

  return count
end

local delete_linked_object_id = function(
    object_tag_api, api_db, object_id, tag_type_id, linked_object_id
  )
  local post_query = " AND " .. object_tag_api.DB_FIELD_OBJ_ID_ .. "='" .. object_id .. "'"
                  .. " AND tag_type_id='" .. tag_type_id .. "'"
                  .. " AND int_value='" .. linked_object_id .. "'"

  local tags_table_api = object_tag_api.get_tags_table_api(api_db)

  local count = try(
      "INTERNAL_ERROR",
      tags_table_api:delete_many(1, post_query)
    )

  return count
end


local delete_tag = function (object_tag_api, api_db, tag_type_id)
  local tags_table_api = object_tag_api.get_tags_table_api(api_db)

  local post_query = " AND tag_type_id='" .. tag_type_id .. "'"

  local count = try(
      "INTERNAL_ERROR",
      tags_table_api:delete_many(object_tag_api.MAX_OBJECTS_, post_query)
    )

  return count
end

--------------------------------------------------------------------------------

local delete_obj_tag = function (object_tag_api, api_db, obj_id)
  local tags_table_api = object_tag_api.get_tags_table_api(api_db)

  local post_query = " AND " .. object_tag_api.DB_FIELD_OBJ_ID_ .. "='" .. obj_id .. "'"

  local count = try(
      "INTERNAL_ERROR",
      tags_table_api:delete_many(object_tag_api.MAX_TAG_TYPES_, post_query)
    )
  return count
end


-- TODO: May be non-optimal because of often get_tag_value_type() calls
--       if used for many objects one-by-one
--       Must be parameter 'tags'?
local list_obj_tags = function (object_tag_api, api_db, obj_id, add_value_text)
  local tags_table_api = object_tag_api.get_tags_table_api(api_db)

  local post_query =
      " AND " .. object_tag_api.DB_FIELD_OBJ_ID_ .. "='" .. obj_id .. "'"
   .. " LIMIT " .. 0 .. "," .. object_tag_api.MAX_TAG_TYPES_

  local tags = try("INTERNAL_ERROR", tags_table_api:list(post_query))

  if tags then
    for i = 1, #tags do
      local value_type = object_tag_api.tag_types.get_tag_value_type(
          object_tag_api, api_db, tags[i].tag_type_id
        )

      local store_field = object_tag_api.TAG_VALUE_STORE_FIELD_[value_type]
      if not store_field then
        fail("INTERNAL_ERROR", "tag value has no store field")
      end

      local value = tags[i][store_field]
      if not value then
        fail("INTERNAL_ERROR", "tag value is nil")
      end

      tags[i].value_type = value_type
      tags[i].value = value

      if value_type == object_tag_api.TAG_VALUE_TYPE_.DB_ID then
        tags[i].table = object_tag_api.tag_types.get_linked_object_table(
            object_tag_api, api_db, tags[i].tag_type_id
          )
        tags[i].db_id = tonumber(value)
      end

      if add_value_text then

        if value_type == object_tag_api.TAG_VALUE_TYPE_.ENUM then

          local enum_value = tonumber(value)
          if not enum_value then
            fail("INTERNAL_ERROR", "enum tag value not a number")
          end

          tags[i].value =
            object_tag_api.tag_type_values.get_enum_tag_value_name(
                object_tag_api, api_db, enum_value
              )

        elseif value_type == object_tag_api.TAG_VALUE_TYPE_.DB_ID then

          local table_api = api_db[tags[i].table](api_db)
          local object = try("INTERNAL_ERROR", table_api:get(tonumber(value)))

          if type(object) == "table" then
            tags[i].value = object.name
          else
            tags[i].value = "invalid object id"
          end

        end
      end
    end
  end

  return tags
end


local insert_or_update_obj_tag = function(object_tag_api, api_db, obj_id, tags)
  if not tags then
    return false
  end

  local tags_table_api = object_tag_api.get_tags_table_api(api_db)

  for i = 1, #tags do
    local tag_type_id = tags[i].type_id;

    local data =
    {
      -- Note: no 'id' since it's INSERT
      [object_tag_api.DB_FIELD_OBJ_ID_] = obj_id;
      tag_type_id = tag_type_id;
      -- Note: no 'comment' field by now
    }

    local value_type = object_tag_api.tag_types.get_tag_value_type(
        object_tag_api, api_db, tag_type_id
      )

    local store_field = object_tag_api.TAG_VALUE_STORE_FIELD_[value_type]
    if not store_field then
      fail("INTERNAL_ERROR", "tag value has no store field")
    end

    data[store_field] =
      object_tag_api.TAG_VALUE_SERIALIZER_[value_type](tags[i].value)

    local current_tag = get_obj_tag(object_tag_api, api_db, obj_id, tag_type_id)

    if current_tag then
      data.id = current_tag.id
      try("INTERNAL_ERROR", tags_table_api:update(data))
    else
      try("INTERNAL_ERROR", tags_table_api:insert(data))
    end
  end

  return true
end

local insert_obj_tag = function(object_tag_api, api_db, obj_id, tags)
  if not tags then
    return false
  end

  local tags_table_api = object_tag_api.get_tags_table_api(api_db)

  for i = 1, #tags do
    local tag_type_id = tags[i].type_id;

    local data =
    {
      -- Note: no 'id' since it's INSERT
      [object_tag_api.DB_FIELD_OBJ_ID_] = obj_id;
      tag_type_id = tag_type_id;
      -- Note: no 'comment' field by now
    }

    local value_type = object_tag_api.tag_types.get_tag_value_type(
        object_tag_api, api_db, tag_type_id
      )

    local store_field = object_tag_api.TAG_VALUE_STORE_FIELD_[value_type]
    if not store_field then
      fail("INTERNAL_ERROR", "tag value has no store field")
    end

    data[store_field] =
      object_tag_api.TAG_VALUE_SERIALIZER_[value_type](tags[i].value)

    try("INTERNAL_ERROR", tags_table_api:insert(data))
  end

  return true
end


--------------------------------------------------------------------------------

return
{
  delete = delete_obj_tag;
  list = list_obj_tags;
  insert_or_update = insert_or_update_obj_tag;
  insert = insert_obj_tag;
  --
  delete_tag_enum_value = delete_tag_enum_value;
  delete_tag_db_id_value = delete_tag_db_id_value;
  delete_linked_object_id = delete_linked_object_id;
  delete_tag = delete_tag;
}
