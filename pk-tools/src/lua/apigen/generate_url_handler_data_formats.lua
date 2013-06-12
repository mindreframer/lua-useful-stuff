--------------------------------------------------------------------------------
-- generate_url_handler_data_formats.lua: api url handlers generator
-- This file is a part of pk-tools library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------

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

local is_number
      = import 'lua-nucleo/type.lua'
      {
        'is_number'
      }

local assert_is_string
      = import 'lua-nucleo/typeassert.lua'
      {
        'assert_is_string'
      }

local walk_tagged_tree
      = import 'pk-core/tagged-tree.lua'
      {
        'walk_tagged_tree'
      }

local create_io_formats
      = import 'apigen/util.lua'
      {
        'create_io_formats'
      }

local make_loggers
      = import 'pk-core/log.lua'
      {
        'make_loggers'
      }

--------------------------------------------------------------------------------

local log, dbg, spam, log_error = make_loggers(
    "generate_url_handler_data_formats", "GUD"
  )

--------------------------------------------------------------------------------

local generate_url_handler_data_formats
do
  local Q = function(str)
    return ("%q"):format(str)
  end

  -- Note no format data needed for api:static_url.

  local down, up = { }, { }
  do
    local url_down = function(walkers, data)
      walkers.cat_ [[
--------------------------------------------------------------------------------
-- ]] (data.name) [[

--------------------------------------------------------------------------------

do
  local format = { }
  local builder = { }

]]
    end

    local url_up = function(walkers, data)
      walkers.cat_ [[
  FORMATS[]] (Q(data.name)) [[] = format
  BUILDERS[]] (Q(data.name)) [[] = builder
  CLIENT_API_QUERY_URLS[]] (Q(data.name)) [[] = ]] (Q(data.name)) [[

end

]]
    end

    down["api:cacheable_url"] = url_down
    down["api:url"] = url_down
    down["api:url_with_dynamic_output_format"] = url_down
    down["api:raw_url"] = url_down

    up["api:cacheable_url"] = url_up
    up["api:url"] = url_up
    up["api:url_with_dynamic_output_format"] = url_up

    -- TODO: Reduce copy-paste
    up["api:raw_url"] = function(walkers, data)
      walkers.cat_ [[
  -- Raw output format
  -- (Should not be called, all is to be handled in the url handler.)

  local build_renderer = function()
    fail("INTERNAL_ERROR", "cant' build raw format renderer")
  end

  format.xml_output_renderer = function()
    fail("INTERNAL_ERROR", "cant' render raw format")
  end

  format.json_output_renderer = function()
    fail("INTERNAL_ERROR", "cant' render raw format")
  end

  format.luabins_output_renderer = function()
    fail("INTERNAL_ERROR", "cant' render raw format")
  end

  builder.output_format_is_raw = true

  builder.build_renderer = build_renderer

  FORMATS[]] (Q(data.name)) [[] = format
  BUILDERS[]] (Q(data.name)) [[] = builder
  CLIENT_API_QUERY_URLS[]] (Q(data.name)) [[] = ]] (Q(data.name)) [[

end

]]
    end

--------------------------------------------------------------------------------

    down["api:input"] = function(walkers, data)
      assert(walkers.child_count_ == nil)
      walkers.child_count_ = 0
      walkers.nesting_ = 0
      walkers.inside_node_ = false

      local use_get = data.use_GET -- TODO: Hack! Validate this at least!

      walkers.cat_ [[
  format.input_loader = function(api_context)
]]
      if use_get then
      walkers.cat_ [[
    local REQUEST = api_context:get_request()
]]
      else
      walkers.cat_ [[
    local REQUEST = api_context:post_request()
]]
      end

      walkers.cat_ [[

    return
    {
]]
    end

    up["api:input"] = function(walkers, data)
      walkers.nesting_ = nil
      walkers.inside_node_ = nil
      if walkers.child_count_ == 0 then
        -- TODO: Do not get post request etc. then!
        walkers.cat_ [[
      -- No input parameters
]]
      end

      walkers.cat_ [[
    }
  end

]]

      walkers.child_count_ = nil
    end

--------------------------------------------------------------------------------

    local formats
    do
      -- TODO: Reduce copy-paste

      local context = { }

      local common_format = function(checker, input, output)
        return function()
          return
          {
            checker = checker;
            input = input;
            output = output;
          }
        end
      end

      context.string = function(min, max)
        return
        {
          checker = "string";
          param = { min, max };
          input = "leaf";
          output = "named_cdata";
        }
      end

      context.identifier = function(min, max)
        return
        {
          checker = "string";
          param = { min, max };
          input = "leaf";
          output = "leaf";
        }
      end

      context.url = function()
        return
        {
          checker = "string";
          param = { 1, 256 };
          input = "leaf";
          output = "leaf";
        }
      end

      context.db_id = common_format("db_id", "leaf", "leaf")

      context.number = common_format("number", "leaf", "leaf")
      -- API 3.0 TODO: check and remove comment
      context.boolean = common_format("boolean", "leaf", "leaf")

      context.integer = common_format("integer", "leaf", "leaf")
      context.nonnegative_integer = common_format(
          "nonnegative_integer",
          "leaf",
          "leaf"
        )

      context.text = common_format("text", "leaf", "named_cdata")
      context.uuid = common_format("uuid", "leaf", "leaf")

      context.file = common_format("file", "leaf", "leaf")

      context.ilist = function()
        return
        {
          checker = "ilist";
          input = "ilist";
          output = "ilist";
        }
      end

      context.dictionary = function()
        return
        {
          checker = "dictionary";
          input = false; -- Note no input!
          output = "dictionary";
        }
      end

      context.node = function()
        return
        {
          checker = "node";
          input = false; -- Note no input!
          output = "node";
        }
      end

      context.list_node = function()
        return
        {
          checker = "node";
          param = { "list_node" };
          input = "node";
          output = "node";
        }
      end

      context.int_enum = function(enum_name)
        return
        {
          checker = "int_enum";
          param = { enum_name };
          input = "leaf";
          output = "leaf";
        }
      end

      context.string_enum = function(enum_name)
        return
        {
          checker = "string_enum";
          param = { enum_name };
          input = "leaf";
          output = "leaf";
        }
      end

      context.optional = function(data)
        data.optional = true
        return data
      end

      context.root = function(data)
        data.root = true
        return data
      end

      formats = create_io_formats(context)
    end

--------------------------------------------------------------------------------

    local get_checker_name_and_params = function(format)
      local checker_name = format.checker

      local param_1, param_2
      if format.param then
        param_1, param_2 = format.param[1], format.param[2]
      end

      if is_number(param_1) then
        param_1 = tostring(param_1)
      end

      if is_number(param_2) then
        param_2 = tostring(param_2)
      end

      assert_is_string(checker_name)
      if param_1 then assert_is_string(param_1) end
      if param_2 then assert_is_string(param_2) end

      return checker_name, param_1, param_2
    end

--------------------------------------------------------------------------------

    local cat_check = function(cat, checker_name, is_optional, param_1, param_2, data)
      local flag_optional = "false"
      if is_optional then flag_optional = "true" end

      cat [[check.]] (checker_name)
          [[(REQUEST, ]] (flag_optional)
          [[, ]] (Q(data.tag))
          [[, ]] (Q(data.name))

      if param_1 then
        cat [[, ]] (param_1) -- Note parameter is not quoted
      end

      if param_2 then
        cat [[, ]] (param_2) -- Note parameter is not quoted
      end

      cat [[)]]

      return cat
    end

    local cat_check_in_node = function(cat, checker_name, is_optional, param_1, param_2, data)
      local flag_optional = "false"
      if is_optional then flag_optional = "true" end

      cat [[{ checker = ]] (Q(checker_name))
          [[, is_optional = ]] (flag_optional)
          [[, tag = ]] (Q(data.tag))
          [[, field = ]] (Q(data.name))

      if param_1 then
        cat [[, ]] (param_1) -- Note parameter is not quoted
      end

      if param_2 then
        cat [[, ]] (param_2) -- Note parameter is not quoted
      end

      cat [[}]]

      return cat
    end

    local handlers = {}
    do
      local cat_nesting = function(walkers)
        -- TODO: Cache offsets!
        return walkers.cat_ [[    ]] (([[  ]]):rep(walkers.nesting_))
      end

      local N = cat_nesting

      handlers.leaf = { }

      handlers.leaf.up = function(
          walkers,
          is_optional,
          checker_name,
          param_1,
          param_2,
          data
        )
        walkers.child_count_ = walkers.child_count_ + 1

        if walkers.inside_node_ then
          walkers.cat_ [[
]] N(walkers) (data.name) [[ = ]]
      cat_check_in_node(walkers.cat_, checker_name, is_optional, param_1, param_2, data)
      [[;
]]
        else
          walkers.cat_ [[
]] N(walkers) (data.name) [[ = ]]
      cat_check(walkers.cat_, checker_name, is_optional, param_1, param_2, data)
      [[;
]]
        end
      end

      handlers.ilist = { }

      handlers.ilist.down = function(
          walkers,
          is_optional,
          checker_name,
          param_1,
          param_2,
          data
        )
          local flag_optional = "false"
          if is_optional then flag_optional = "true" end

          local list_name = data.name

          walkers.cat_ [[
]] N(walkers) (list_name) [[ = check.]] (checker_name) [[(
]] N(walkers) [[    REQUEST, ]] (flag_optional)
          [[, ]] (Q(data.tag)) [[, ]] (Q(data.name)) [[,
]]
          walkers.nesting_ = walkers.nesting_ + 1
      end

      handlers.ilist.up = function(
          walkers,
          is_optional,
          checker_name,
          param_1,
          param_2,
          data
        )
          walkers.cat_ [[
]] N(walkers) [[);
]]
          walkers.nesting_ = walkers.nesting_ - 1
      end

      handlers.node = { }

      handlers.node.down = function(
          walkers,
          is_optional,
          checker_name,
          param_1,
          param_2,
          data
        )
          walkers.cat_ [[
]] N(walkers) [[{
]]
          walkers.inside_node_ = true
      end

      handlers.node.up = function(
          walkers,
          is_optional,
          checker_name,
          param_1,
          param_2,
          data
        )
          walkers.inside_node_ = false

          walkers.cat_ [[
]] N(walkers) [[}
]]
      end
    end

    local input_check = function(dir, format)
      arguments(
          "string", dir,
          "table", format
        )

      local checker_name, param_1, param_2 = get_checker_name_and_params(format)

      local is_optional = not not format.optional

      if format.input == false then
        return function(walkers, data)
          error("unsupported input tag " .. data.id)
        end
      end

      local handler_name = assert_is_string(format.input)

      local handler = assert(
          handlers[handler_name],
          "unknown "..handler_name
        )[dir]

      if not handler then
        return function(walkers, data) -- TODO: Cache this!
          if dir == "down" then
            walkers.nesting_ = walkers.nesting_ + 1
          elseif dir == "up" then
            walkers.nesting_ = walkers.nesting_ - 1
          end
        end
      end

      return function(walkers, data)
        if dir == "down" then
          walkers.nesting_ = walkers.nesting_ + 1
        end
        handler(
            walkers,
            is_optional,
            checker_name,
            param_1,
            param_2,
            data
          )
        if dir == "up" then
          walkers.nesting_ = walkers.nesting_ - 1
        end
      end
    end

--------------------------------------------------------------------------------

    for name, format in pairs(formats) do
      down["input:"..name] = input_check("down", format)
      up["input:"..name] = input_check("up", format)
    end

--------------------------------------------------------------------------------

    local output_check_and_format
    do
      -- TODO: Add better indentation to generated data
      --       (or use source autoindenter from jsle)
      -- TODO: Generate functions here. Don't use schema builders!

      local handlers = { }
      do
        local cat_nesting = function(walkers)
          -- TODO: Cache offsets!
          return walkers.cat_ (([[  ]]):rep(walkers.nesting_))
        end

        local N = cat_nesting

        local cat_method = function(
            walkers,
            method_name,
            is_optional,
            is_root,
            data
          )
          if is_optional then
            method_name = "optional_" .. method_name
          end

          local cat = walkers.cat_

          cat [[
]] N(walkers) [[    builder:]] (method_name)

          local field, node = data.name, data.node_name

          if is_root then
            field = nil -- TODO: ?!
          end

          if node == field then
            node = nil
          end

          if node then
            cat [[ (]] ((field == nil) and [[nil]] or (Q(field)))
            [[, ]] (Q(node)) [[)]]
          else
            cat [[ ]] (Q(field))
          end

          return cat
        end

        handlers.leaf = { }

        handlers.leaf.up = function(
            walkers,
            is_optional,
            is_root,
            checker_name,
            checker_param_1,
            checker_param_2,
            data
          )
          assert(is_root == false)

          cat_method(walkers, "attribute", is_optional, is_root, data) [[;
]]
        end

        handlers.named_cdata = { }

        handlers.named_cdata.up = function(
            walkers,
            is_optional,
            is_root,
            checker_name,
            checker_param_1,
            checker_param_2,
            data
          )
          assert(is_root == false)

          cat_method(walkers, "named_cdata", is_optional, is_root, data) [[;
]]
        end

        handlers.ilist = { }

        handlers.ilist.down = function(
            walkers,
            is_optional,
            is_root,
            checker_name,
            checker_param_1,
            checker_param_2,
            data
          )
          -- TODO: Do call check.*!
          -- TODO: Validate in validator that list has a single child only!
          cat_method(walkers, "ilist", is_optional, is_root, data) [[

]] N(walkers) [[    {
]]
        end

        handlers.ilist.up = function(
            walkers,
            is_optional,
            is_root,
            checker_name,
            checker_param_1,
            checker_param_2,
            data
          )
          walkers.cat_ [[
]] N(walkers) [[    };
]]
        end

        handlers.dictionary = { }

        handlers.dictionary.down = function(
            walkers,
            is_optional,
            is_root,
            checker_name,
            checker_param_1,
            checker_param_2,
            data
          )
          -- TODO: Do call check.*!
          -- TODO: Validate in validator that list has a single child only!
          cat_method(walkers, "dictionary", is_optional, is_root, data) [[

]] N(walkers) [[    {
]]
        end

        handlers.dictionary.up = function(
            walkers,
            is_optional,
            is_root,
            checker_name,
            checker_param_1,
            checker_param_2,
            data
          )
          walkers.cat_ [[
]] N(walkers) [[    };
]]
        end

        handlers.node = { }

        handlers.node.down = function(
            walkers,
            is_optional,
            is_root,
            checker_name,
            checker_param_1,
            checker_param_2,
            data
          )

          -- TODO: Do call check.*!

          local method_name = "node"
          if checker_param_1 then -- list nodes has type "list_node"
            method_name = checker_param_1 -- TODO: Check is string?
          end

          cat_method(walkers, method_name, is_optional, is_root, data)
          [[

]] N(walkers) [[    {
]]
        end

        handlers.node.up = function(
            walkers,
            is_optional,
            is_root,
            checker_name,
            checker_param_1,
            checker_param_2,
            data
          )
          walkers.cat_ [[
]] N(walkers) [[    };
]]
        end
      end

      output_check_and_format = function(dir, format)
        local checker_name, checker_param_1, checker_param_2
              = get_checker_name_and_params(
                  format
                )

        local is_optional = not not format.optional
        local is_root = not not format.root
        local handler_name = assert_is_string(format.output)

        local handler = assert(
            handlers[handler_name],
            "unknown "..handler_name
          )[dir]

        -- TODO: Optional should be handled in check!

        return handler and function(walkers, data)
          if dir == "down" then
            walkers.nesting_ = walkers.nesting_ + 1
          end
          handler(
              walkers,
              is_optional,
              is_root,
              checker_name,
              checker_param_1,
              checker_param_2,
              data
            )
          if dir == "up" then
            walkers.nesting_ = walkers.nesting_ - 1
          end
        end or function(walkers, data) -- TODO: Cache this!
          if dir == "down" then
            walkers.nesting_ = walkers.nesting_ + 1
          elseif dir == "up" then
            walkers.nesting_ = walkers.nesting_ - 1
          end
        end
      end
    end

--------------------------------------------------------------------------------

    -- TODO: Separate render_json vs render_jsonp, render jsonp only
    --       if explicitly allowed in the url schema, not decide that
    --       at run-time
    local COMMON_OUTPUT_TAIL = [[
  local render_xml = assert(
      xml_schema_builder:commit(
          build_renderer(xml_schema_builder)
        )
    )
  local render_json = assert(
      json_schema_builder:commit(
          build_renderer(json_schema_builder)
        )
    )

  local render_luabins = assert(
      luabins_schema_builder:commit(
          build_renderer(luabins_schema_builder)
        )
    )

  format.xml_output_renderer = function(api_context, value, extra)
    return try("INTERNAL_ERROR", render_xml(value))
  end

  format.json_output_renderer = function(api_context, value, extra)
    -- TODO: Separate that jsonp stuff to jsonp_output_renderer. Handle it smarter.
    local json = try("INTERNAL_ERROR", render_json(value))
    if extra then
      return extra .. "(" .. json .. ");"
    end
    return json
  end

  format.luabins_output_renderer = function(api_context, value, extra)
    return try("INTERNAL_ERROR", render_luabins(value))
  end

  builder.output_format_is_dynamic = false

  builder.build_renderer = build_renderer
]]

--------------------------------------------------------------------------------

    down["api:output"] = function(walkers, data)
      walkers.nesting_ = 0

      -- TODO: Hack. Remove local variable.
      walkers.cat_ [[
  local build_renderer = function(builder)
    local schema =
]]
    end

    up["api:output"] = function(walkers, data)
      walkers.nesting_ = nil

      walkers.cat_ [[
    return schema
  end

]] (COMMON_OUTPUT_TAIL) [[

]]
    end

--------------------------------------------------------------------------------

    down["api:output_with_events"] = function(walkers, data)
      walkers.nesting_ = 1

      -- TODO: Hack. Remove local variable.
      walkers.cat_ [[
  local build_renderer = function(builder)
    local schema = builder:node(nil, "ok")
    {
      builder:node "result"
      {
]]
    end

    -- TODO: Reuse built events renderer?!
    up["api:output_with_events"] = function(walkers, data)
      walkers.nesting_ = nil

      walkers.need_events_renderer_ = true

      walkers.cat_ [[
      };
      build_events_renderer(builder);
    }

    return schema
  end

]] (COMMON_OUTPUT_TAIL) [[

]]
    end

--------------------------------------------------------------------------------

    up["api:dynamic_output_format"] = function(walkers, data)
      walkers.cat_ [[
  -- Dynamic output format
  -- (Should not be called, all is to be handled in the url handler.)

  local build_renderer = function()
    fail("INTERNAL_ERROR", "cant' build dynamic format renderer")
  end

  format.xml_output_renderer = function()
    fail("INTERNAL_ERROR", "cant' render dynamic format")
  end

  format.json_output_renderer = function()
    fail("INTERNAL_ERROR", "cant' render dynamic format")
  end

  format.luabins_output_renderer = function()
    fail("INTERNAL_ERROR", "cant' render dynamic format")
  end

  builder.output_format_is_dynamic = true

  builder.build_renderer = build_renderer

]]
    end

    up["api:dynamic_output_format"] = function(walkers, data)
      walkers.cat_ [[
  -- Dynamic output format
  -- (Should not be called, all is to be handled in the url handler.)

  local build_renderer = function()
    fail("INTERNAL_ERROR", "cant' build dynamic format renderer")
  end

  format.xml_output_renderer = function()
    fail("INTERNAL_ERROR", "cant' render dynamic format")
  end

  format.json_output_renderer = function()
    fail("INTERNAL_ERROR", "cant' render dynamic format")
  end

  format.luabins_output_renderer = function()
    fail("INTERNAL_ERROR", "cant' render dynamic format")
  end

  builder.output_format_is_dynamic = true

  builder.build_renderer = build_renderer

]]
    end

--------------------------------------------------------------------------------

    for name, format in pairs(formats) do
      down["output:"..name] = output_check_and_format("down", format)
      up["output:"..name] = output_check_and_format("up", format)
    end

--------------------------------------------------------------------------------

  end

  generate_url_handler_data_formats = function(schema, file_header)
    arguments(
        "table",  schema,
        "string", file_header
      )

    local cat, concat = make_concatter()

    local walkers =
    {
      down = down;
      up = up;
      --
      cat_ = cat;
      child_count_ = nil;
      nesting_ = nil;
      need_events_renderer_ = false;
    }

    for i = 1, #schema do
      walk_tagged_tree(schema[i], walkers, "id")
    end

    -- TODO: Elaborate on this
    local extra_imports = { }

    if walkers.need_events_renderer_ then
      extra_imports[#extra_imports + 1] = [[
local build_events_renderer
      = import 'logic/webservice/client_events.lua'
      {
        'build_events_renderer'
      }
]]
    end

    return [[
--------------------------------------------------------------------------------
-- formats.lua: generated information on url handlers data formats
]] .. file_header .. [[
--------------------------------------------------------------------------------
-- WARNING! Do not change manually.
--          Generated by apigen.lua
--------------------------------------------------------------------------------

local luabins = require 'luabins'

--------------------------------------------------------------------------------

local tkeys,
      tidentityset
      = import 'lua-nucleo/table-utils.lua'
      {
        'tkeys',
        'tidentityset'
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

local try
      = import 'pk-core/error.lua'
      {
        'try'
      }

local PARTNER_NAMES
      = import 'pk-engine/webservice/partner.lua'
      {
        'PARTNER_NAMES'
      }

local check = import 'pk-engine/webservice/client_api/check.lua' ()

]] .. table.concat(extra_imports, "\n") .. [[
--------------------------------------------------------------------------------

local xml_schema_builder = make_xml_schema_builder()
local json_schema_builder = make_json_schema_builder()
local luabins_schema_builder = make_luabins_schema_builder()

--------------------------------------------------------------------------------

local FORMATS = { }
local BUILDERS = { }
local CLIENT_API_QUERY_URLS = { } -- TODO: Should be in a separate file

]] .. concat() .. [[
--------------------------------------------------------------------------------

-- TODO: ?! Why is it not in some static file, but here, in generated one?
local make_output_format_manager
do
  local build_url_output_format = function(self, url, builder)
    local builder_info = BUILDERS[url]
    if not builder_info then
      return nil, "unknown url " .. tostring(url)
    end

    -- TODO: Support this case in /multiquery anyway (use delayed render)
    if builder_info.output_format_is_dynamic then
      return nil, "cant build dynamic url format for " .. tostring(url)
    end

    if builder_info.output_format_is_raw then
      return nil, "cant build raw url format for " .. tostring(url)
    end

    return builder_info.build_renderer(builder)
  end

  make_output_format_manager = function()

    return
    {
      build_url_output_format = build_url_output_format;
    }
  end
end

--------------------------------------------------------------------------------

return
{
  FORMATS = FORMATS;
  --
  make_output_format_manager = make_output_format_manager;
}
]]
  end
end

--------------------------------------------------------------------------------

return
{
  generate_url_handler_data_formats = generate_url_handler_data_formats;
}
