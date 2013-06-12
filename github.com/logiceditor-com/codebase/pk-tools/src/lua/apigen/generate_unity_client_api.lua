--------------------------------------------------------------------------------
-- generate_unity_client_api.lua: unity client api generator
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
    "generate_unity_client_api", "GUC"
  )

--------------------------------------------------------------------------------

-- TODO: Support static URLs as well?

local generate_unity_client_api
do
  -- TODO: Should be js-escape.
  local Q = function(str)
    return ("%q"):format(str)
  end

  -- TODO: ?!
  local unity_handler_name = function(url)
    return url:gsub("^/", ""):gsub("/", "_"):gsub("-", "")
  end

  -- Note no format data needed for api:static_url.

  local down, up = { }, { }
  do
    local url_down = function(walkers, data)
      walkers.cat_in_args_, walkers.concat_in_args_ = make_concatter()
      walkers.cat_form_fields_, walkers.concat_form_fields_ = make_concatter()
      walkers.cat_out_args_, walkers.concat_out_args_ = make_concatter()
      walkers.cat_error_codes_, walkers.concat_error_codes_ = make_concatter()
    end

    local url_up = function(walkers, data)

      local in_args = walkers.concat_in_args_(",\n    ")

      -- TODO: Lazy hack. Generate proper code at the first place.
      local form_fields = walkers.concat_form_fields_()
        :gsub("\n", "\n  ")
        :gsub("[ ]+\n", "\n")
        :gsub("[ ]+$", "")
        :gsub("^[ \n]+", "")

      local error_codes = walkers.concat_error_codes_()

      walkers.cat_ [[

////////////////////////////////////////////////////////////////////////////////
// ]] (data.name) [[

function ]] (unity_handler_name(data.name)) [[ (
    base_address : String]] ((#in_args > 0) and ",\n    " or "") [[
]] (in_args) [[

  )
{
]]

      if #form_fields > 0 then
        walkers.cat_ [[
  var form = new WWWForm();

  ]] (form_fields) [[

  yield process(base_address + ]] (Q(data.name)) [[, form);
]]
      else
        walkers.cat_ [[
  yield process(base_address + ]] (Q(data.name)) [[, null);
]]
      end

        walkers.cat_ [[

/*
Reply format:
-------------

]] (walkers.concat_out_args_()) [[

Custom errors:
--------------

]] (#error_codes > 0 and error_codes or "(None)\n") [[

*/
}
]]

      walkers.cat_in_args_, walkers.concat_in_args_ = nil, nil
      walkers.cat_form_fields_, walkers.concat_form_fields_ = nil, nil
      walkers.cat_out_args_, walkers.concat_out_args_ = nil, nil
      walkers.cat_error_codes_, walkers.concat_error_codes_ = nil, nil
    end

    down["api:cacheable_url"] = url_down
    down["api:url"] = url_down
    down["api:url_with_dynamic_output_format"] = url_down
    down["api:raw_url"] = url_down

    up["api:cacheable_url"] = url_up
    up["api:url"] = url_up
    up["api:url_with_dynamic_output_format"] = url_up

    up["api:raw_url"] = function(walkers, data)
      walkers.cat_out_args_ [[(Raw format)]] "\n"

      return url_up(walkers, data)
    end

--------------------------------------------------------------------------------

    down["api:input"] = function(walkers, data)
      assert(walkers.register_arg_ == nil)

      walkers.register_arg_ = function(name, js_type)
        walkers.cat_in_args_(name .. [[ : ]] .. js_type)

        -- TODO: Hack. Generalize?
        if js_type ~= "Array" then
          walkers.cat_form_fields_(
              [[form.AddField(]] .. (Q(name))
           .. [[, ]] .. (name) .. [[);]]
           .. "\n"
            )
        else
          -- TODO: HACK! Do not loop by keys, but extract data
          --       at specific keys instead. Schema knows them!
          -- TODO: Support nested arrays
          --       (should be done authomatically when above would work).
          walkers.cat_form_fields_ [[

form.AddField("]] (name) [[[size]", ]] (name) [[.length);
for (var i = 0; i < ]] (name) [[.length; ++i) {
  for (var k in ]] (name) [[[i].Keys) {
    form.AddField(
        "]] (name) [[[" + (i + 1) + "][" + k + "]",
        ]] (name) [[[i][k]
      );
  }
}
]]
          return "break" -- TODO: UBERHACK. Traverse truly!
        end
      end

    end

    up["api:input"] = function(walkers, data)
      walkers.register_arg_ = nil
    end

--------------------------------------------------------------------------------

    -- TODO: Generalize with generate_data_formats
    local formats
    do
      -- TODO: Cache results
      local registerer = function(js_type, input, output)
        return function() -- TODO: Handle extra parameters here?
          if input == nil then
            input = true
          end

          -- TODO: WTF?!
          if js_type ~= "Array" then
            js_type = "String" -- As per client programmer's request
          end

          return
          {
            output = output or "leaf";
            input = input and function(walkers, data)
              return walkers.register_arg_(
                  assert(data.node_name or data.name),
                  js_type
                )
            end or false;
          }
        end
      end

      -- TODO: Note that registerer function is hacked to override js_type!

      local context = { }

      -- API 3.0 TODO: check and remove comment
      context.boolean = registerer("String")
      context.file = registerer("String")
      context.string = registerer("String")
      context.identifier = registerer("String")
      context.url = registerer("String")
      context.db_id = registerer("Int32")
      context.number = registerer("Int32")
      context.integer = registerer("Int32")
      context.nonnegative_integer = registerer("Int32")
      context.text = registerer("String", true, "named_cdata")
      context.uuid = registerer("String")
      context.ilist = registerer("Array", true, "ilist")
      context.node = registerer("Object", false, "node")
      context.list_node = registerer("Object", true, "node")

      context.int_enum = function(enum_name)
        return registerer(enum_name)()
      end

      context.string_enum = function(enum_name)
        -- TODO: ?! More likely to be just "String".
        return registerer(enum_name)()
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

    local create_input_handler = function(format)
      arguments("table", format)

      -- TODO: Handle this somehow?
      local is_optional = not not format.optional

      return function(walkers, data)
        if not format.input then
          -- TODO: Ensure this is checked in validate_schema as well
          error("unsupported input tag " .. data.id)
        end

        return format.input(walkers, data)
      end
    end

--------------------------------------------------------------------------------

    for name, format in pairs(formats) do
      down["input:"..name] = create_input_handler(format)
    end

--------------------------------------------------------------------------------

    local create_output_handler
    do
      local handlers = { }
      do
        local cat_nesting = function(walkers)
          -- TODO: Cache offsets!
          return walkers.cat_out_args_ (([[  ]]):rep(walkers.nesting_))
        end

        local N = cat_nesting

        local cat_leaf = function(walkers, data, format)
          -- TODO: Handle is_optional and is_root?
          return N(walkers) (
              assert(data.node_name or data.name)
            ) " : " (data.tag) "\n"
        end

        local cat_node_down = function(walkers, data, format)
          cat_leaf(walkers, data, format)
          N(walkers) "{\n"
        end

        local cat_node_up = function(walkers, data, format)
          N(walkers) "}\n"
        end

        handlers.leaf = { }
        handlers.leaf.up = cat_leaf

        handlers.named_cdata = { }
        handlers.named_cdata.up = cat_leaf

        handlers.ilist = { }
        handlers.ilist.down = cat_node_down
        handlers.ilist.up = cat_node_up

        handlers.node = { }
        handlers.node.down = cat_node_down
        handlers.node.up = cat_node_up
      end

      create_output_handler = function(dir, format)

        -- TODO: Handle is_optional and is_root?

        local handler_name = assert_is_string(format.output)

        local handler = assert(
            handlers[handler_name],
            "unknown "..handler_name
          )[dir]

        return handler and function(walkers, data)
          if dir == "down" then
            walkers.nesting_ = walkers.nesting_ + 1
          end
          handler(walkers, data, format)
          if dir == "up" then
            walkers.nesting_ = walkers.nesting_ - 1
          end
        end or function(walkers, data) -- TODO: Cache this
          if dir == "down" then
            walkers.nesting_ = walkers.nesting_ + 1
          elseif dir == "up" then
            walkers.nesting_ = walkers.nesting_ - 1
          end
        end
      end
    end

--------------------------------------------------------------------------------

    down["api:output"] = function(walkers, data)
      walkers.nesting_ = 0
    end

    up["api:output"] = function(walkers, data)
      walkers.nesting_ = nil
    end

--------------------------------------------------------------------------------

    down["api:output_with_events"] = function(walkers, data)
      walkers.nesting_ = 1

      -- TODO: ?!
      walkers.cat_out_args_ [[
ok
{
  result
  {
]]
    end

    -- TODO: Reuse built events renderer?!
    up["api:output_with_events"] = function(walkers, data)
      walkers.nesting_ = nil

      -- TODO: ?!
      walkers.cat_out_args_ [[
  }
  events { }
}
]]
    end

--------------------------------------------------------------------------------

    for name, format in pairs(formats) do
      down["output:"..name] = create_output_handler("down", format)
      up["output:"..name] = create_output_handler("up", format)
    end

--------------------------------------------------------------------------------

    up["api:dynamic_output_format"] = function(walkers, data)
      walkers.cat_out_args_ [[(Dynamic format)]] "\n"
    end

--------------------------------------------------------------------------------

    local additional_errors =
    {
      "ACCOUNT_NOT_FOUND";
      "ACCOUNT_TEMPORARILY_UNAVAILABLE";
      "BANNED";
      "DUPLICATE_EUID";
      "GARDEN_IS_GIFT";
      "NOT_ALLOWED";
      "NOT_ENOUGH_MONEY";
      "NOT_ENOUGH_SPACE";
      "NOT_FOUND";
      "NOT_READY";
      "NOT_SUPPORTED";
      "PLANT_IS_ALIVE";
      "SERVER_FULL";
      "SLOT_ALREADY_BOUGHT";
      "SLOT_NOT_AVAILABLE";
      "UNAUTHORIZED";
      "UNREGISTERED";
    }

    local additional_error_handler = function(walkers, data)
      walkers.cat_error_codes_ " * " (data.tag) "\n"
    end

    for i = 1, #additional_errors do
      up["err:"..additional_errors[i]] = additional_error_handler
    end

--------------------------------------------------------------------------------

  end

  generate_unity_client_api = function(schema)
    arguments(
        "table",  schema
      )

    local cat, concat = make_concatter()

    local walkers =
    {
      down = down;
      up = up;
      --
      cat_ = cat;
    }

    cat [[
////////////////////////////////////////////////////////////////////////////////
// Communicator.js: generated unity client API
////////////////////////////////////////////////////////////////////////////////
// WARNING! Do not change manually.
// Generated by apigen.lua
////////////////////////////////////////////////////////////////////////////////

var currNode : XMLNode;
var dataNode : String;
var nodeSet = 0;

function processError(node : XMLNode) {
  currNode = node;
  nodeSet = 1;
  return null;
}

function processNode(node : XMLNode) {
  currNode = node;
  nodeSet = 1;
}

function process(
    address : String,
    form: WWWForm
  )
{
  var www;
  if (form != null) {
    www = new WWW (address, form);
  } else {
    www = new WWW (address);
  }
  yield www;
  var parser = new XMLParser();
  dataNode = www.data;
  var node = parser.Parse(www.data);
  if(node.Contains("error")) {
    processError(node);
  } else {
    processNode(node);
  }
}

function any(base_address : String)
{
  yield process(base_address, null);
}

////////////////////////////////////////////////////////////////////////////////
// Generated handlers
////////////////////////////////////////////////////////////////////////////////
]]

    for i = 1, #schema do
      walk_tagged_tree(schema[i], walkers, "id")
    end

    return concat()
  end
end

--------------------------------------------------------------------------------

return
{
  generate_unity_client_api = generate_unity_client_api;
}
