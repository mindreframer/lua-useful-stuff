--------------------------------------------------------------------------------
-- serialized_list.lua: webservice database handlers for serialized list
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

local log, dbg, spam, log_error = make_loggers("webservice/db/serialized_list", "SRL")

--------------------------------------------------------------------------------

local get_list = function (table_api, list_field_name, obj_id)
  local object = try("INTERNAL_ERROR", table_api:get(obj_id))
  if object[list_field_name] == nil or object[list_field_name] == "" then
    return {}
  end

  local _, data = try("INTERNAL_ERROR", luabins.load(object[list_field_name]))
  return data
end

local update_list = function (
    table_api, obj_id_field_name, list_field_name, obj_id, data
  )

  local serialized_data = try("INTERNAL_ERROR", luabins.save(data));
  return try("INTERNAL_ERROR", table_api:update(
      {
        [obj_id_field_name] = obj_id,
        [list_field_name] = serialized_data
      }
    ))
end

--------------------------------------------------------------------------------

local delete = function (self, list_item_id)
  local list = get_list(self.table_api_, self.list_field_name_, self.obj_id_)
  if not list then
    fail("INTERNAL_ERROR", "serialized list not found")
  end

  local num = #list
  for i = 1, num do
    if list[i][self.list_item_id_field_name_] == list_item_id then
      table.remove(list, i)
      update_list(
          self.table_api_,
          self.obj_id_field_name_, self.list_field_name_, self.obj_id_,
          list
        )
      return true
    end
  end

  return false
end

local get = function (self, list_item_id)
  local list = get_list(self.table_api_, self.list_field_name_, self.obj_id_)
  if not list then
    fail("INTERNAL_ERROR", "serialized list not found")
  end

  for i = 1, #list do
    if list[i][self.list_item_id_field_name_] == list_item_id then
      return list[i]
    end
  end

  return false
end

local list = function (self)
  return get_list(self.table_api_, self.list_field_name_, self.obj_id_) or {}
end

local insert = function(self, data)
  local list = get_list(self.table_api_, self.list_field_name_, self.obj_id_)
  if not list then
    fail("INTERNAL_ERROR", "serialized list not found")
  end

  list[#list + 1] = data

  update_list(
      self.table_api_,
      self.obj_id_field_name_, self.list_field_name_, self.obj_id_,
      list
    )

  return true
end

local update = function(self, data)
  local list = get_list(self.table_api_, self.list_field_name_, self.obj_id_)
  if not list then
    -- Note: may normally occur only if the object was created recently
    list = {}
  end

  local list_item_id = data[self.list_item_id_field_name_]
  if not list_item_id then
    fail("INTERNAL_ERROR", "list item doesn't contain primary key")
  end

  for i = 1, #list do
    if list[i][self.list_item_id_field_name_] == list_item_id then
      list[i] = data

      update_list(
          self.table_api_,
          self.obj_id_field_name_, self.list_field_name_, self.obj_id_,
          list
        )
      return true
    end
  end

  return false
end


local make_serialized_list_api = function(
    table_api, obj_id_field_name, list_field_name, obj_id,
    list_item_id_field_name
  )

  return
  {
    delete = delete;
    get = get;
    insert = insert;
    list = list;
    update = update;
    --
    table_api_ = table_api;
    obj_id_ = obj_id;
    obj_id_field_name_ = obj_id_field_name;
    list_field_name_ = list_field_name;
    list_item_id_field_name_ = list_item_id_field_name;
  }
end

--------------------------------------------------------------------------------

return
{
  make_serialized_list_api = make_serialized_list_api;
}
