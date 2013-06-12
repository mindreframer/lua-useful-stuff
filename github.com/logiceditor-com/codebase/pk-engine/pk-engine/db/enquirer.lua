--------------------------------------------------------------------------------
-- enquirer.lua: query wrapper for concrete table
-- This file is a part of pk-engine library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
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

local empty_table,
      tmap_values
      = import 'lua-nucleo/table.lua'
      {
        'empty_table',
        'tmap_values'
      }

local get_by_id,
      get_by_data,
      insert_one,
      update_one,
      update_or_insert_one,
      increment_counter,
      subtract_values_one,
      add_values_one,
      delete_by_id,
      delete_many,
      delete_all,
      list,
      count
      = import 'pk-engine/db/query.lua'
      {
        'get_by_id',
        'get_by_data',
        'insert_one',
        'update_one',
        'update_or_insert_one',
        'increment_counter',
        'subtract_values_one',
        'add_values_one',
        'delete_by_id',
        'delete_many',
        'delete_all',
        'list',
        'count'
      }

local make_loggers
      = import 'pk-core/log.lua'
      {
        'make_loggers'
      }

--------------------------------------------------------------------------------

local log, dbg, spam, log_error = make_loggers("query_wrapper", "QWR")

--------------------------------------------------------------------------------

local make_enquirer
do
  local methods
  do
    local wrap_method = function(fn)
      return function(self, db_conn, ...)
        return fn(db_conn, self.table_name_, self.primary_key_, ...)
      end
    end

    methods = tmap_values(
        wrap_method,
        {
          get_by_id = get_by_id;
          get_by_data = get_by_data;
          insert_one = insert_one;
          update_one = update_one;
          update_or_insert_one = update_or_insert_one;
          increment_counter = increment_counter;
          subtract_values_one = subtract_values_one;
          add_values_one = add_values_one;
          delete_by_id = delete_by_id;
          delete_many = delete_many;
          delete_all = delete_all;
          list = list;
          count = count;
        }
      )
  end

  make_enquirer = function(table_name, primary_key, features)
    features = features or empty_table
    arguments(
        "string", table_name,
        "string", primary_key,
        "table", features
      )

    local enquirer =
    {
      --
      table_name_ = table_name;
      primary_key_ = primary_key;
    }

    for name, fn in pairs(methods) do
      -- TODO: Filter methods by features
      enquirer[name] = fn
    end

    return enquirer
  end
end

--------------------------------------------------------------------------------

return
{
  make_enquirer = make_enquirer;
}
