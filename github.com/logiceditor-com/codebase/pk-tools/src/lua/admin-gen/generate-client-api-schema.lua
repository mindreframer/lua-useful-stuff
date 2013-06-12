--------------------------------------------------------------------------------
-- generate-client-api-schema.lua: client api schema generator
-- This file is a part of pk-tools library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------

local make_loggers = import 'pk-core/log.lua' { 'make_loggers' }
local log, dbg, spam, log_error = make_loggers("generate-client-api-schema", "GCS")

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

local tset
      = import 'lua-nucleo/table-utils.lua'
      {
        'tset'
      }

local do_nothing
      = import 'lua-nucleo/functional.lua'
      {
        'do_nothing'
      }

local assert_is_table,
      assert_is_number,
      assert_is_string
      = import 'lua-nucleo/typeassert.lua'
      {
        'assert_is_table',
        'assert_is_number',
        'assert_is_string'
      }

local walk_tagged_tree
      = import 'pk-core/tagged-tree.lua'
      {
        'walk_tagged_tree'
      }

local write_table_handlers,
      write_serialized_list_handlers
      = import 'admin-gen/client-api-handler-writers.lua'
      {
        'write_table_handlers',
        'write_serialized_list_handlers'
      }

local Q, CR, NPAD, table_contains_game_data
      = import 'admin-gen/misc.lua'
      {
        'Q', 'CR', 'NPAD', 'table_contains_game_data'
      }

local make_db_field_visitor,
      wrap_field_down,
      wrap_table_down,
      wrap_table_up,
      wrap_serialized_list_down,
      wrap_serialized_list_up
      = import 'admin-gen/db_field_visitor.lua'
      {
        'make_db_field_visitor',
        'wrap_field_down',
        'wrap_table_down',
        'wrap_table_up',
        'wrap_serialized_list_down',
        'wrap_serialized_list_up'
      }

--------------------------------------------------------------------------------

local generate_client_api_schema
do
  local make_common_field_visitor_cb = function(prefix, whitespaces, type_renderer)
    return function(
        walkers, cat, field_index, raw_type, name, is_optional, size, is_primary
      )
      if not raw_type then
        return false
      end

      if field_index == 1 then
        cat (prefix) [[:]]
      else
        cat (CR) (whitespaces) (prefix) [[:]]
      end

      local type = type_renderer and
        type_renderer(raw_type, is_primary) or raw_type

      cat (type) [[ ]] (Q(name)) [[;]]

      return true
    end
  end

  local down = { }
  do
    down.table = wrap_table_down(table_contains_game_data, nil)

    -- down.list_node = do_nothing

    down.serialized_list = wrap_serialized_list_down(
        nil,
        wrap_field_down(
            function(walkers, data)
              return false, "TEXT", data.name
            end,
            true
          )
      )

    do
      local primary_key = wrap_field_down(function(walkers, data)
        return true, "DB_ID", data.name, false, nil, true
      end)

      local primary_ref = wrap_field_down(function(walkers, data)
        return false, "DB_ID", data.name
      end)


      local serialized_primary_key = wrap_field_down(function(walkers, data)
        return true, "DB_ID", data.name, false, nil, true
      end)

      local serialized_primary_ref = wrap_field_down(function(walkers, data)
        return true, "DB_ID", data.name
      end)

      local bool = wrap_field_down(function(walkers, data)
        return false, "INTEGER", data.name
      end)

      local int = function(size)
        return wrap_field_down(function(walkers, data)
          size = size or assert_is_number(data[1], "bad size")
          return false, "INTEGER", data.name, false, size
        end)
      end

      local password = wrap_field_down(function(walkers, data)
        walkers.password_field = data.name
        return false, "STRING256", data.name
      end)

      local varchar = function(size, is_optional)
        return wrap_field_down(function(walkers, data)
          size = size or assert_is_number(data[1], "bad size")
          return false, (size <= 256 and "STRING256" or "TEXT"), data.name, is_optional
        end)
      end

      local text = wrap_field_down(function(walkers, data)
        return false, "TEXT", data.name
      end)

      local blob = wrap_field_down(function(walkers, data)
        return false, "TEXT", data.name
      end)

      local ref = function(is_optional)
        return wrap_field_down(function(walkers, data)
          return false, "DB_ID", data.name, is_optional
        end)
      end

      local timestamp = wrap_field_down(function(walkers, data)
        return false, "INTEGER", data.name
      end)

      local metadata = wrap_field_down(function(walkers, data)

        if data.admin and data.admin.read_only_fields then
          data.admin.read_only_fields = tset(data.admin.read_only_fields)
        end

        walkers.table_admin_metadata = data.admin

        return false, nil
      end)

      local std_int = int(11)

      down.metadata = metadata

      down.primary_key = primary_key
      down.primary_ref = primary_ref

      down.serialized_primary_key = serialized_primary_key
      down.serialized_primary_ref = serialized_primary_ref

      down.blob = blob
      down.boolean = bool
      down.counter = std_int
      down.flags = std_int
      down.int = std_int
      down.int_enum = std_int
      down.ip = varchar(15)
      down.md5 = varchar(32)
      down.password = password
      down.optional_ip = varchar(15, true)
      down.optional_ref = ref(true)
      down.ref = ref(false)
      down.string = varchar(nil)
      down.text = text
      down.timeofday = std_int
      down.day_timestamp = std_int
      down.timestamp = timestamp
      down.timestamp_created = timestamp
      down.uuid = varchar(37)
      down.weekdays = std_int

      -- down.database = do_nothing
      -- down.key = do_nothing
      -- down.unique_key = do_nothing
    end
  end

--------------------------------------------------------------------------------

  local up = {}
  do
    up.table = wrap_table_up(function(walkers, data)
      local existing_fields = walkers.visitors.existing_field.concat()
      local new_fields = walkers.visitors.new_item_field.concat()
      local updated_fields = walkers.visitors.updated_item_field.concat()

      write_table_handlers(
          walkers.table_admin_metadata,
          assert_is_string(walkers.current_table_name),
          walkers.password_field,
          walkers.template_dir_,
          walkers.dir_out_,
          existing_fields, new_fields, updated_fields
        )
      walkers.table_admin_metadata = nil
      walkers.password_field = nil
    end)

    up.serialized_list = wrap_serialized_list_up(function(walkers, data)
      local existing_fields = walkers.visitors.existing_field.sl_concat()
      local new_fields = walkers.visitors.new_item_field.sl_concat()
      local updated_fields = walkers.visitors.updated_item_field.sl_concat()

      -- TODO: Implement list metadata
      local list_metadata = {}

      if not walkers.serialized_list_primary_key then
        log(
            "WARNING: Skipped serialized list",
            walkers.current_table_name .. "." .. walkers.current_serialized_list_name,
            "since it has no primary key!"
          )
      else
        write_serialized_list_handlers(
            walkers.table_admin_metadata,
            list_metadata,
            assert_is_string(walkers.current_table_name),
            assert_is_string(walkers.table_primary_key),
            assert_is_string(walkers.current_serialized_list_name),
            assert_is_string(walkers.serialized_list_primary_key),
            walkers.template_dir_,
            walkers.dir_out_,
            existing_fields, new_fields, updated_fields
          )
      end
    end)
  end

--------------------------------------------------------------------------------

  local add_optional_to_nonprimary = function(raw_type, is_primary)
    if is_primary then
      return raw_type
    end
    return "OPTIONAL_" .. raw_type
  end

  generate_client_api_schema = function(tables, template_dir, dir_out)
    local walkers =
    {
      down = down;
      up = up;
      visitors = {};
      --
      template_dir_ = template_dir;
      dir_out_ = dir_out;
    }

    walkers.visitors.existing_field = make_db_field_visitor(
        walkers,
        make_common_field_visitor_cb("output", "        "),
        make_common_field_visitor_cb("output", "        "),
        false
      );

    walkers.visitors.new_item_field = make_db_field_visitor(
        walkers,
        make_common_field_visitor_cb("input", "    ", add_optional_to_nonprimary),
        make_common_field_visitor_cb("input", "    ", add_optional_to_nonprimary),
        true
      );

    walkers.visitors.updated_item_field = make_db_field_visitor(
        walkers,
        make_common_field_visitor_cb("input", "    ", add_optional_to_nonprimary),
        make_common_field_visitor_cb("input", "    ", add_optional_to_nonprimary),
        false
      );

    for i = 1, #tables do
      walk_tagged_tree(tables[i], walkers, "tag")
    end
  end
end

--------------------------------------------------------------------------------

return
{
  generate_client_api_schema = generate_client_api_schema;
}
