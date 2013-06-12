--------------------------------------------------------------------------------
-- generate_url_handlers_index.lua: api url handlers generator
-- This file is a part of pk-tools library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------
-- TODO: Generalize with admin: Must take all texts from separate file

local arguments,
      optional_arguments,
      method_arguments
      = import 'lua-nucleo/args.lua'
      {
        'arguments',
        'optional_arguments',
        'method_arguments',
        'eat_true'
      }

local make_concatter
      = import 'lua-nucleo/string.lua'
      {
        'make_concatter'
      }

local walk_tagged_tree
      = import 'pk-core/tagged-tree.lua'
      {
        'walk_tagged_tree'
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

--------------------------------------------------------------------------------

local log, dbg, spam, log_error = make_loggers(
    "generate_url_handlers_index", "GUI"
  )

--------------------------------------------------------------------------------

local generate_url_handler_index
do
  -- TODO: URL wrapper would need data format!

  local concat_url = function(base, suffix)
    if base:sub(#base) == "/" then
      base = base:sub(1, #base - 1)
    end
    if suffix:sub(1, 1) == "/" then
      suffix = suffix:sub(2, #suffix)
    end
    return base .. "/" .. suffix
  end

  local cat_static_output_format = function(walkers, url, format, data_name)
      return walkers.cat_ [[
      FORMATS[]] (
        ("%q"):format(data_name)
        ) [[].]] (format) [[_output_renderer,
]]
  end

  local cat_dynamic_output_format = function(walkers, url, format, data_name)
      return walkers.cat_ [[
      make_]] (format) [[_schema_builder,
]]
  end

  local cat_dynamic_url = function(
      walkers,
      uhw_method,
      url,
      format,
      data_name,
      cat_output_format
    )
    -- TODO: Do not pass output_renderer for dynamic_format_handlers
    walkers.cat_ [[
  HANDLERS[]] (
      ("%q"):format(concat_url(walkers.base_url_, url))
    ) [[] = ]] (uhw_method) [[(
      handler_fn,
      FORMATS[]] (("%q"):format(data_name)) [[].input_loader,
]] cat_output_format(walkers, url, format, data_name) [[
      response_handler_fn and response_handler_fn or ]] (format) [[_response,
      error_handler_fn and error_handler_fn or common_]] (format) [[_error
    )
]]

    return walkers.cat_
  end

  local down_dynamic_handler = function(walkers, data)
    walkers.handler_tag_ = nil
  end

  local down_raw_handler = down_dynamic_handler

  -- TODO: Reuse this
  local handler_info =
  {
    ["api:handler"] =
    {
      method = "url:api";
      export = "handle_api";
      wrappers = false;
      cat_output_format = cat_static_output_format;
    };
    ["api:session_handler"] =
    {
      method = "url:api";
      export = "handle_api_session";
      wrappers = { "create_session_checker"};
      cat_output_format = cat_static_output_format;
    };
    ["api:client_session_handler"] =
    {
      method = "url:api";
      export = "handle_api_session";
      wrappers = { "create_client_session_checker"};
      cat_output_format = cat_static_output_format;
    };
    ["api:session_handler_with_events"] =
    {
      method = "url:api";
      export = "handle_api_session_with_events";
      wrappers = { "create_session_checker", "create_event_reporter" };
      cat_output_format = cat_static_output_format;

      raw_handler = function(self, walkers, data)
        walkers.need_event_reporter_ = true
      end;
    };
    ["api:dynamic_output_format_handler"] =
    {
      method = "url:api_with_dynamic_output_format";
      export = "handle_api_with_dynamic_output_format";
      wrappers = false;
      cat_output_format = cat_dynamic_output_format;
    };
  }

  local up_dynamic_handler = function(walkers, data)
    local handler_filename = walkers.handler_path_prefix_ .. data.filename

    assert(walkers.handler_tag_)

    local handler_info = assert(handler_info[walkers.handler_tag_])

    if handler_info.raw_handler then
      handler_info.raw_handler(handler_info, walkers, data)
    end

    walkers.cat_ [[
do
  local ]] (
      (not handler_info.wrappers) and "handler_fn" or handler_info.export
    ) [[, error_handler_fn, response_handler_fn

        = import ']] (handler_filename) [['
        {
          ']] (handler_info.export) [[',
          'error_handler',
          'response_handler'
        }
]]

    if not handler_info.wrappers then
      walkers.cat_ "\n"
    else
      walkers.cat_ [[
  local handler_fn = ]]

      for i = 1, #handler_info.wrappers do
        walkers.cat_ (handler_info.wrappers[i]) [[(]]
      end

      walkers.cat_ (handler_info.export)

      for i = 1, #handler_info.wrappers do
        walkers.cat_ [[)]]
      end

      walkers.cat_ [[

]]
    end

    assert(#data.urls > 0)

    -- TODO: Reuse handlers for aliases (for same formats only)!
    for i = 1, #data.urls do
      local url_info = data.urls[i]

      -- TODO: Generalize
      if is_string(url_info) then
        local url = url_info
        cat_dynamic_url(
            walkers,
            handler_info.method,
            "xml" .. url, "xml", data.name,
            handler_info.cat_output_format
          )
        cat_dynamic_url(
            walkers,
            handler_info.method,
            "json" .. url, "json", data.name,
            handler_info.cat_output_format
          )
        cat_dynamic_url(
            walkers,
            handler_info.method,
            "luabins" .. url, "luabins", data.name,
            handler_info.cat_output_format
          )
      else
        cat_dynamic_url(
            walkers,
            handler_info.method,
            url_info.url, url_info.format, data.name,
            handler_info.cat_output_format
          )
      end
    end

    -- TODO: Forbid internal calls for dynamic output format stuff!
    walkers.cat_ [[
  INTERNAL_CALL_HANDLERS[]] (
    ("%q"):format(data.name)) [[] = url:internal_call(
      handler_fn,
      FORMATS[]] (("%q"):format(data.name)) [[].input_loader
    )
end

]]
  end

  local down, up = { }, { }

  down["api:static_url"] = function(walkers, data)
    local handler_filename = walkers.handler_path_prefix_ .. data.filename

    -- TODO: Cache handlers for aliases!
    for i = 1, #data.urls do
      local url = data.urls[i]
      walkers.cat_ [[
HANDLERS[]] (("%q"):format(concat_url(walkers.base_url_, url)))
[[] = url:static(]] (("%q"):format(handler_filename)) [[)
INTERNAL_CALL_HANDLERS[]] (("%q"):format(url)) [[] = function()
  error("Internal calls for static URLs are not supported")
end
]]
    end

    walkers.cat_ "\n"

    return "break" -- All done
  end

  down["api:cacheable_url"] = down_dynamic_handler
  down["api:url"] = down_dynamic_handler
  down["api:url_with_dynamic_output_format"] = down_dynamic_handler
  down["api:raw_url"] = down_raw_handler

  local down_handler = function(walkers, data)
    walkers.handler_tag_ = data.id
  end

  down["api:handler"] = down_handler
  down["api:session_handler"] = down_handler
  down["api:client_session_handler"] = down_handler
  down["api:session_handler_with_events"] = down_handler
  down["api:dynamic_output_format_handler"] = down_handler
  down["api:raw_handler"] = down_handler

  -- NOTE: cacheability is to be handled in generated nginx config
  -- TODO: Generate that nginx config?
  up["api:cacheable_url"] = up_dynamic_handler
  up["api:url"] = up_dynamic_handler
  up["api:url_with_dynamic_output_format"] = up_dynamic_handler

  -- TODO: Generalize with up_dynamic_handler
  up["api:raw_url"] = function(walkers, data)
    local handler_filename = walkers.handler_path_prefix_ .. data.filename

    assert(walkers.handler_tag_)

    walkers.cat_ [[
do
  local handler_fn, error_handler_fn, response_handler_fn
        = import ']] (handler_filename) [['
        {
          'handle_raw',
          'error_handler',
          'response_handler'
        }

]]

    assert(#data.urls > 0)

    -- TODO: Reuse handlers for aliases (for same formats only)!
    for i = 1, #data.urls do
      local url_info = data.urls[i]
      -- TODO: Handle non-string url_info or verify that it is string!
      local base_url, url
      if is_table(url_info) then
        base_url = url_info.base_url or walkers.base_url_
        url = url_info.url
      else
        base_url = walkers.base_url_
        url = url_info
      end
      walkers.cat_ [[
  HANDLERS[]] (
      ("%q"):format(concat_url(base_url, url))
    ) [[] = url:raw(
      handler_fn,
      FORMATS[]] (("%q"):format(data.name)) [[].input_loader,
      response_handler_fn,
      error_handler_fn
    )
INTERNAL_CALL_HANDLERS[]] (("%q"):format(url)) [[] = function()
  error("Internal calls for raw URLs are not supported")
end
]]
    end

    walkers.cat_ [[
end

]]
  end

  generate_url_handler_index = function(
      schema,
      project_specific_headers,
      handler_path_prefix,
      data_formats_filename, -- TODO: Straighten these out!
      db_tables_filename,
      webservice_request_filename,
      base_url,
      file_header
    )
    arguments(
        "table", schema,
        "string", project_specific_headers,
        "string", handler_path_prefix,
        "string", data_formats_filename,
        "string", db_tables_filename,
        "string", webservice_request_filename,
        "string", base_url,
        "string", file_header
      )

    local cat, concat = make_concatter()

    local walkers =
    {
      down = down;
      up = up;
      --
      cat_ = cat;
      handler_path_prefix_ = handler_path_prefix;
      handler_tag_ = nil;
      base_url_ = base_url;
      need_event_reporter_ = false;
    }

    for i = 1, #schema do
      walk_tagged_tree(schema[i], walkers, "id")
    end
    schema.header = schema.header or ""

    -- TODO: Elaborate on this
    local extra_imports =
    {
      assert(project_specific_headers);
    }

    if walkers.need_event_reporter_ then
      extra_imports[#extra_imports + 1] = [[
local create_event_reporter
      = import 'logic/webservice/db/client_event.lua'
      {
        'create_event_reporter'
      }
]]
    end

    return [[
--------------------------------------------------------------------------------
-- handlers.lua: generated information on url handlers
]] .. file_header .. [[
--------------------------------------------------------------------------------
-- WARNING! Do not change manually.
--          Generated by apigen.lua
--------------------------------------------------------------------------------

local common_html_error,
      common_xml_error,
      common_json_error,
      common_luabins_error,
      html_response,
      xml_response,
      json_response,
      luabins_response
      = import 'pk-engine/webservice/response.lua'
      {
        'common_html_error',
        'common_xml_error',
        'common_json_error',
        'common_luabins_error',
        'html_response',
        'xml_response',
        'json_response',
        'luabins_response'
      }

local make_xml_schema_builder
      = import 'pk-engine/xml_schema_builder.lua'
      {
        'make_xml_schema_builder'
      }

local make_json_schema_builder
      = import 'pk-engine/json_schema_builder.lua'
      {
        'make_json_schema_builder'
      }

local make_luabins_schema_builder
      = import 'pk-engine/luabins_schema_builder.lua'
      {
        'make_luabins_schema_builder'
      }

local make_url_handler_wrapper
      = import 'pk-engine/webservice/client_api/url_handler_wrapper.lua'
      {
        'make_url_handler_wrapper'
      }

--------------------------------------------------------------------------------

local FORMATS,
      make_output_format_manager
      = import ']] .. data_formats_filename .. [['
      {
        'FORMATS',
        'make_output_format_manager'
      }

local TABLES = import ']] .. db_tables_filename .. [[' ()

local get_www_game_config,
      get_www_admin_config
      = import ']] .. webservice_request_filename .. [['
      {
        'get_www_game_config',
        'get_www_admin_config'
      }

]] .. table.concat(extra_imports, '\n') .. [[
--------------------------------------------------------------------------------

local INTERNAL_CALL_HANDLERS = { }

local url = make_url_handler_wrapper(
    TABLES,
    get_www_game_config,
    get_www_admin_config,
    make_output_format_manager(),
    INTERNAL_CALL_HANDLERS
  )

--------------------------------------------------------------------------------

local HANDLERS = { }

-- TODO: UBERHACK! Assuming INTERNAL_CALL_HANDLERS is defined
--       in project_specific_data.HEADER.
--local INTERNAL_CALL_HANDLERS = { }
assert(INTERNAL_CALL_HANDLERS)

--------------------------------------------------------------------------------

]] .. concat() .. [[
--------------------------------------------------------------------------------

-- TODO: Hack. Export only handler_fns themselves
--       (along with urls and formats metadata).
return
{
  HANDLERS = HANDLERS;
  INTERNAL_CALL_HANDLERS = INTERNAL_CALL_HANDLERS;
  URL_HANDLER_WRAPPER = url; -- TODO: Hack? Export getter instead?
}
]]
  end
end

--------------------------------------------------------------------------------

return
{
  generate_url_handler_index = generate_url_handler_index;
}
