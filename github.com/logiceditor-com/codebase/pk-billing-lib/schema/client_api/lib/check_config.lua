--------------------------------------------------------------------------------
-- check_config.lua
-- This file is a part of pk-billing-lib library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------


api:export "check_config"
{
  exports =
  {
    "load_config_data_schema";
    "load_config";
  };

  handler = function()
    local get_config_data_walkers
      = import 'pk-core/config_dsl.lua'
      {
        'get_data_walkers'
      }
    --------------------------------------------------------------------------------

    local load_config_data_schema
    do
      local extra_env =
      {
        import = import; -- Trusted sandbox
      }

      load_config_data_schema = function(schema_chunk)
        arguments("function", schema_chunk)
        return load_data_schema(schema_chunk, extra_env, { "cfg" })
      end
    end

    --------------------------------------------------------------------------------

    local load_config_data
    do
      load_config_data = function(schema, data, env)
        if is_function(schema) then
          schema = load_config_data_schema(schema)
        end

        arguments(
            "table", schema,
            "table", data
          )

        local checker = get_config_data_walkers()
          :walk_data_with_schema(
              schema,
              data,
              data -- use data as environment for string_to_node
            )
          :get_checker()

        if not checker:good() then
          return checker:result()
        end

        return data
      end
    end

    --------------------------------------------------------------------------------

    local raw_config_table_key = unique_object()

    local load_config
    do
      load_config = function(
          schema,
          CONFIG -- config table here
        )
        arguments(
            "table", schema,
            "table", CONFIG
          )

        if CONFIG.import == import then
          CONFIG.import = nil -- TODO: Hack. Use metatables instead
        end

        if CONFIG.rawget == rawget then
          CONFIG.rawget = nil -- TODO: Hack. Use metatables instead
        end

        return load_config_data(schema, make_config_environment(CONFIG))
      end
    end

  end;
}
