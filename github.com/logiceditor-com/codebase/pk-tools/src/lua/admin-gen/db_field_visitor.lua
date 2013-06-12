--------------------------------------------------------------------------------
-- db_field_visitor.lua: visitor of DB fields
-- This file is a part of pk-tools library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------

local make_loggers = import 'pk-core/log.lua' { 'make_loggers' }
local log, dbg, spam, log_error = make_loggers("db_field_visitor", "DFV")

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

local make_concatter,
      fill_placeholders
      = import 'lua-nucleo/string.lua'
      {
        'make_concatter',
        'fill_placeholders'
      }

local Q, CR, NPAD
      = import 'admin-gen/misc.lua'
      {
        'Q', 'CR', 'NPAD'
      }

--------------------------------------------------------------------------------

local make_db_field_visitor = function(
      walkers,
      field_visitor_cb,
      serialized_list_field_visitor_cb,
      ignore_primary_id_in_table
    )

  local visitor = {}

  visitor.on_table_begin = function()
    local cat, concat = make_concatter()
    visitor.cat = cat
    visitor.concat = concat
    visitor.field_index = 1
  end;

  visitor.on_table_end = function()
    visitor.cat = nil
    visitor.concat = nil
    visitor.field_index = nil
  end;

  visitor.visit_table_field = function(data, is_primary_id, ...)
    if is_primary_id then
      walkers.table_primary_key = data.name
      if ignore_primary_id_in_table then
        return
      end
    end

    if field_visitor_cb then
      local was_output = field_visitor_cb(
          walkers, visitor.cat, visitor.field_index, ...
        )

      if was_output then
        visitor.field_index = visitor.field_index + 1
      end
    end

  end;


  visitor.on_serialized_list_begin = function()
    local cat, concat = make_concatter()
    visitor.sl_cat = cat
    visitor.sl_concat = concat
    visitor.sl_field_index = 1
  end;

  visitor.on_serialized_list_end = function()
    visitor.sl_cat = nil
    visitor.sl_concat = nil
    visitor.sl_field_index = nil
  end;

  visitor.visit_serialized_list_field = function(data, is_primary_id, ...)
    if is_primary_id then
      walkers.serialized_list_primary_key = data.name
      --if ignore_primary_id_in_serialized_list then
      --  return
      --end
    end

    if serialized_list_field_visitor_cb then
      local was_output = serialized_list_field_visitor_cb(
          walkers, visitor.sl_cat, visitor.sl_field_index, ...
        )

      if was_output then
        visitor.sl_field_index = visitor.sl_field_index + 1
      end
    end

  end;

  return visitor;
end

--------------------------------------------------------------------------------

local wrap_field_down = function(param_generator, always_use_table_field_visitor)
  if always_use_table_field_visitor == nil then
    always_use_table_field_visitor = false
  end

  return function(walkers, data)
    if not walkers.current_table_name
      and not walkers.current_serialized_list_name
    then
      return
    end

    local params = { param_generator(walkers, data) }

    for _, v in pairs(walkers.visitors) do
      if not always_use_table_field_visitor and v.sl_field_index ~= nil then
        v.visit_serialized_list_field(data, unpack(params))
      else
        v.visit_table_field(data, unpack(params))
      end
    end
  end
end

--------------------------------------------------------------------------------

local wrap_table_down = function(valid_table_indicator, callback)
  return function(walkers, data)
    assert(walkers.current_table_name == nil)
    assert(walkers.table_primary_key == nil)

    if not valid_table_indicator or
      valid_table_indicator(data.name)
    then
      walkers.current_table_name = data.name
    else
      return
    end

    for _, v in pairs(walkers.visitors) do
      v.on_table_begin()
    end

    if callback then return callback(walkers, data) end
  end
end

local wrap_table_up = function(callback)
  return function(walkers, data)
    if walkers.current_table_name then
      if callback then
        callback(walkers, data)
      end

      for _, v in pairs(walkers.visitors) do
        v.on_table_end()
      end

      walkers.current_table_name = nil
      walkers.table_primary_key = nil
    end
  end
end

--------------------------------------------------------------------------------

local wrap_serialized_list_down = function(valid_serialized_list_indicator, callback)
  return function(walkers, data)
    assert(walkers.serialized_list == nil)
    assert(walkers.serialized_list_primary_key == nil)

    if not valid_serialized_list_indicator or
      valid_serialized_list_indicator(data.name)
    then
      walkers.current_serialized_list_name = data.name
    else
      return
    end

    for _, v in pairs(walkers.visitors) do
      v.on_serialized_list_begin()
    end

    if callback then return callback(walkers, data) end
  end
end

local wrap_serialized_list_up = function(callback)
  return function(walkers, data)
    if walkers.current_serialized_list_name then
      if callback then
        callback(walkers, data)
      end

      for _, v in pairs(walkers.visitors) do
        v.on_serialized_list_end()
      end

      walkers.current_serialized_list_name = nil
      walkers.serialized_list_primary_key = nil
    end
  end
end

--------------------------------------------------------------------------------

return
{
  make_db_field_visitor = make_db_field_visitor;

  wrap_field_down = wrap_field_down;

  wrap_table_down = wrap_table_down;
  wrap_table_up = wrap_table_up;

  wrap_serialized_list_down = wrap_serialized_list_down;
  wrap_serialized_list_up = wrap_serialized_list_up;
}
