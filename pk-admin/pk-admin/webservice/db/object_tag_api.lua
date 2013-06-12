--------------------------------------------------------------------------------
-- object_tag_api.lua: api for work with object custom tag
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

local object_tags_table_api
      = import 'pk-admin/webservice/db/object_tag.lua' ()

local tag_types_table_api
      = import 'pk-admin/webservice/db/object_tag_type.lua' ()

local tag_type_values_table_api
      = import 'pk-admin/webservice/db/object_tag_type_value.lua' ()


--------------------------------------------------------------------------------

local log, dbg, spam, log_error = make_loggers("webservice/db/object_tag_api", "TTG")

--------------------------------------------------------------------------------

local make_table_api = function(table_name)
  return function (api_db)
    local table_api = api_db[table_name](api_db)
    if not table_api then
      fail("INTERNAL_ERROR", table_name .." table not found")
    end
    return table_api
  end
end

local make_object_tag_api = function(
    tag_value_type, tag_value_names, tag_value_store_field, tag_value_serializer,
    tags_table_name, tag_types_table_name, tag_type_values_table_name,
    --
    db_field_obj_id,
    --
    max_tag_types, max_tag_enum_values, max_objects
  )

  return
  {
    object_tags = object_tags_table_api;
    tag_types = tag_types_table_api;
    tag_type_values = tag_type_values_table_api;
    --
    get_tags_table_api            = make_table_api(tags_table_name);
    get_tag_types_table_api       = make_table_api(tag_types_table_name);
    get_tag_type_values_table_api = make_table_api(tag_type_values_table_name);
    --
    DB_FIELD_OBJ_ID_ = db_field_obj_id;
    MAX_OBJECTS_ = max_objects;
    MAX_TAG_TYPES_ = max_tag_types;
    MAX_TAG_ENUM_VALUES_ = max_tag_enum_values;
    --
    TAG_VALUE_TYPE_ = tag_value_type;
    TAG_VALUE_NAMES_ = tag_value_names;
    TAG_VALUE_STORE_FIELD_ = tag_value_store_field;
    TAG_VALUE_SERIALIZER_ = tag_value_serializer;
  }
end

--------------------------------------------------------------------------------

return
{
  make_object_tag_api = make_object_tag_api;
}
