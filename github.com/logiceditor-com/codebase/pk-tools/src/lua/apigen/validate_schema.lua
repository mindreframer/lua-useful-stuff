--------------------------------------------------------------------------------
-- validate_schema.lua: api schema validator
-- This file is a part of pk-tools library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------

local arguments,
      optional_arguments,
      method_arguments,
      eat_true
      = import 'lua-nucleo/args.lua'
      {
        'arguments',
        'optional_arguments',
        'method_arguments',
        'eat_true'
      }

local is_table,
      is_string
      = import 'lua-nucleo/type.lua'
      {
        'is_table',
        'is_string'
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

local empty_table,
      timap,
      tclone,
      tset,
      tijoin_many,
      tappend_many,
      tsetof,
      tset_many
      = import 'lua-nucleo/table-utils.lua'
      {
        'empty_table',
        'timap',
        'tclone',
        'tset',
        'tijoin_many',
        'tappend_many',
        'tsetof',
        'tset_many'
      }

local do_nothing,
      invariant
      = import 'lua-nucleo/functional.lua'
      {
        'do_nothing',
        'invariant'
      }

local make_checker
      = import 'lua-nucleo/checker.lua'
      {
        'make_checker'
      }

local make_concatter
      = import 'lua-nucleo/string.lua'
      {
        'make_concatter'
      }

local make_loggers
      = import 'pk-core/log.lua'
      {
        'make_loggers'
      }

local walk_tagged_tree
      = import 'pk-core/tagged-tree.lua'
      {
        'walk_tagged_tree'
      }

local list_globals_in_handler,
      check_globals
      = import 'pk-core/api_globals.lua'
      {
        'list_globals_in_handler',
        'check_globals'
      }

--------------------------------------------------------------------------------

local log, dbg, spam, log_error = make_loggers("validate_schema", "VSC")

--------------------------------------------------------------------------------

local validate_schema
do
  local wensure = function(walkers, data, msg, ...)
    walkers.checker_:ensure(
        "bad " .. tostring(data.id)
     .. (data.name and (" '" .. tostring(data.name) .. "'") or "")
     .. ": ".. msg,
        ...
      )
  end

  local wfail = function(walkers, data, msg)
    walkers.checker_:fail(
        "bad " .. tostring(data.id)
     .. (data.name and (" '" .. tostring(data.name) .. "'") or "")
     .. ": " .. msg
      )
  end

  local common_check_node = function(walkers, data)
    wensure(
        walkers, data,
        "broken id",
        data.id == (tostring(data.namespace)..":"..tostring(data.tag))
      )
  end

  local common_check_url_node = function(walkers, data)
    common_check_node(walkers, data)
    -- TODO: Check data.name is valid url better.

    wensure(
        walkers, data,
        "filename missing",
        data.filename -- TODO: Better validate filename
      )

    wensure(
        walkers, data,
        "urls missing",
        data.urls -- TODO: Better validate urls
      )

    for i = 1, #data.urls do
      local info = data.urls[i]
      if not is_string(info) then
        wensure(walkers, data, "bad urls["..i.."] type", is_table(info))

        local url, format, base_url = info.url, info.format, info.base_url

        wensure(
            walkers, data,
            "bad or missing `url' field in urls["..i.."]",
            is_string(url),
            type(url)
          )

        -- TODO: Check better. Format is ignored on api:raw_url
        if not base_url then
          wensure( -- Hack
              walkers, data,
              "bad or missing `format' field in urls["..i.."]",
              (
                format == "xml"
                  or format == "json"
                  or format == "luabins"
              ),
              tostring(format)
            )
        end

        -- TODO: Check better. Base URL is useful only for api:raw_url
        if base_url then
          wensure(
              walkers, data,
              "bad `base_url' field in urls["..i.."]",
              (
                is_string(base_url)
              ),
              tostring(base_url)
            )
        end
      end
    end

  end

  local init_validators_table = function(on_error, validators)
    validators = validators or { }

    if is_string(on_error) then
      on_error = invariant(on_error) -- Should return error message
    end

    arguments(
        "function", on_error,
        "table", validators
      )

    return setmetatable(
        validators,
        {
          __index = function(t, id)
            return function(walkers, data)
              wfail(walkers, data, on_error(walkers, data), 2)
              return "break" -- For the case when this is "down" handler.
            end
          end;
        }
      )
  end

  local is_valid_identifier = function(v)
    if not is_string(v) then
      return nil, "must be a string"
    end

    if v:find("[^a-zA-Z0-9_%-]") then
      return nil, "contains invalid characters"
    end

    return true
  end

  local data_type_set

  -- TODO: Check more
  local nesting_up
  local specialized_validators = { }
  do
    -- TODO: Separate admin types from game types.
    --       Introduce project-specific types instead.
    -- TODO: Reuse create_io_formats here. Until that keep them synchronized!
    local leaf_data_types =
    {
      -- Admin types --
      "DB_ID",
      "IP",
      "TEXT",
      "TIMEOFDAY",
      "WEEKDAYS",

      "FILE",
      "OPTIONAL_FILE",

      "OPTIONAL_DB_ID",
      "OPTIONAL_INTEGER",
      "OPTIONAL_NUMBER",
      "OPTIONAL_IP",
      "OPTIONAL_STRING256",
      "OPTIONAL_STRING128",
      "OPTIONAL_STRING64",
      "OPTIONAL_IDENTIFIER16",
      "OPTIONAL_TEXT",
      "OPTIONAL_TIMEOFDAY",
      "OPTIONAL_WEEKDAYS",

      -- Game types --

      "ACCOUNT_ID";
      "API_VERSION";
      "DELTA_TIME";
      "DESCRIPTION";
      "EXTRA_INFO";
      "FULLNAME";
      "GARDEN_ARTICUL_ID";
      "GARDEN_ID";
      "GARDEN_SLOT_ID";
      "GARDEN_SLOT_TYPE_ID";
      "INTEGER";
      "NUMBER";
      "MONEY_GAME";
      "MONEY_REAL";
      "NICKNAME";
      "OPTIONAL_ACCOUNT_ID";
      "OPTIONAL_PLANT_GROUP_ID";
      "OPTIONAL_SESSION_ID";
      "PLANT_ARTICUL_ID";
      "PLANT_CARE_ACTION_ID";
      "PLANT_GROUP_ID";
      "PLANT_GROWTH_STAGE_NUMBER";
      "PLANT_HEALTH";
      "PLANT_ID";
      "PRICE_GAME";
      "PRICE_REAL";
      "SESSION_ID";
      "SESSION_TTL";
      "STAT_EVENT_ID";
      "TIMESTAMP";
      "TITLE";
      "RESOURCE_SIZE";
      "RESOURCE_ID";
      "ABSOLUTE_URL";
      "OPTIONAL_ABSOLUTE_URL";
      "RELATIVE_URL";
      "PUBLIC_PARTNER_API_TOKEN";
      "STRING256"; -- Not recommended to use.
      "STRING128"; -- Not recommended to use.
      "STRING64";
      "IDENTIFIER16";
      "BLOB"; -- Not recommended to use.
      "CLIENT_API_QUERY_PARAM";
      "CLIENT_API_QUERY_URL";

      -- API 3.0 added; TODO - remove this comment after check
      "MODIFIER_ARTICUL_ID";
      "GARDEN_POINTS";
      "BOOLEAN";
      "ACTION_ID";
      "PLANT_LEVEL";
      "GARDEN_LEVEL";
      "MODIFIER_INCOME";
      "MODIFIER_RESISTANCE";
      "POSITIVE_INTEGER";
      "MODIFIER_GIFT_ID";
      "REDEEM_CODE";
      "EXCHANGE_RATE";
      "MONEY_PARTNER";
      "MODIFIER_PERMIRIAD_VALUE";
      "MODIFIER_LINEAR_VALUE";
      "GIFT_TYPE_ID";
      "GIFT_ID";
      "PARAMETER_NAME";
      "FOTOSTRANA_ACCOUNT_ID";
      "FOTOSTRANA_SESSION_ID";
      "IPHONE_ACCOUNT_ID";
      "IPHONE_SESSION_ID";
      "TEST_ACCOUNT_ID";
      "TEST_SESSION_ID";
      "MOIMIR_VID";
      "MOIMIR_AUTHENTIFICATION_KEY";
      "VKONTAKTE_USER_ID";
      "VKONTAKTE_AUTH_KEY";
--------------------------------------------------------------------------------
-- TYPES FOR SPPIP
--------------------------------------------------------------------------------
      "PAY_SYSTEM_ID";
      "PAY_SYSTEM_SUBID";
      "APPLICATION_ID";
      "BILLING_ACCOUNT_ID";
      "PAYMENT_ID";
      "OPTIONAL_PAYMENT_ID";
      "OPTIONAL_PAY_SYSTEM_ID";
--------------------------------------------------------------------------------
-- TYPES FOR MRX
--------------------------------------------------------------------------------
      "COUNTRY_CODE";
      "OPTIONAL_COUNTRY_CODE";
--------------------------------------------------------------------------------
-- BEGIN POSTCARDS
--------------------------------------------------------------------------------
-- TODO MOVE ELSEWHERE
      "POSTCARD_GROUP_ID";
      "COMMON_TEXT_ID";
      "POSTCARD_ID";
--------------------------------------------------------------------------------
-- END POSTCARDS
--------------------------------------------------------------------------------
    }

    local input_node_data_types =
    {
      "OPTIONAL_LIST";
      "LIST_NODE";
      "LIST";
    }

    local output_root_node_data_types =
    {
      "ROOT_LIST";
      "ROOT_NODE";
    }

    local output_root_node_data_types_set = tset(output_root_node_data_types)

    local output_node_data_types = tijoin_many(
        output_root_node_data_types,
        {
          "LIST_NODE";
          "LIST";
          "OPTIONAL_LIST";
          "DICTIONARY";
          "OPTIONAL_DICTIONARY";
          "NODE";
          "OPTIONAL_NODE";
        }
      )

    data_type_set = tset_many(
        leaf_data_types,
        input_node_data_types,
        output_node_data_types
      )

    local standard_errors =
    {
      "BAD_INPUT";
      "INTERNAL_ERROR";
      "FATAL_ERROR";
      "GAME_CLOSED";
      "SESSION_EXPIRED";
    }

    local standard_error_set = tset(standard_errors)

    -- TODO: Catch duplicate error codes
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

      -- API 3.0 added; TODO - remove this comment after check
      "NO_REDEEMS_LEFT";
      "USED_SLOT";
      ----------------------------------------------------------------------
      -- BEGIN pk-banners
      ----------------------------------------------------------------------

      "DUPLICATE_WEBSITE_URL";

      ----------------------------------------------------------------------
      -- END pk-banners
      ----------------------------------------------------------------------

      ----------------------------------------------------------------------
      -- BEGIN pk-banners
      ----------------------------------------------------------------------

      "APPLICATION_NOT_FOUND";
      "PAYSYSTEM_NOT_FOUND";
    }

    local doc_tags =
    {
      "description";
      "comment";
    }

    local nesting_down = function(fn)
      return function(walkers, data)
        walkers.nesting_ = walkers.nesting_ + 1
        -- dbg("down", walkers.nesting_, data.id)

        return fn(walkers, data)
      end
    end

    do
      local handler = function(walkers, data)
        walkers.nesting_ = walkers.nesting_ - 1
        -- dbg("up", walkers.nesting_, data.id)
      end

      nesting_up = setmetatable(
          { },
          {
            __index = function(t, k)
              local v = handler
              t[k] = v
              return v
            end
          }
        )
    end

    local common_check_named_node = function(walkers, data)
      common_check_node(walkers, data)
      wensure(
          walkers, data,
          "bad name",
          is_valid_identifier(data.name),
          tostring(data.name)
        )

      -- TODO: Uncomment and fix this.
      --       Duplicate naming allowed if nodes are in different scope.
      --       (Like in two different output:NODE tags)
      --[[
      wensure(
          walkers, data,
          "duplicate name",
          not walkers.known_names_[data.name],
          tostring(data.name)
        )
      --]]

      if not data.namespace == "err" then -- Hack
        walkers.known_names_[data.name] = true
      end

      if data.namespace == "output" then -- Hack
        walkers.have_output_tag_ = true

        if walkers.nesting_ == 1 then
          walkers.number_of_first_level_output_tags_ =
            walkers.number_of_first_level_output_tags_ + 1

          if walkers.root_only_first_level_tags_ then
            if not output_root_node_data_types_set[data.tag] then
              wfail(
                  walkers, data,
                  "first-level tag in api:output must be a root tag"
                )
            end
          end
        end
      end
    end

    specialized_validators.doc = tsetof(
        nesting_down(common_check_node),
        timap(
            function(v) return "doc:" .. v end,
            doc_tags
          )
      )

    specialized_validators.input = tappend_many(
        tsetof(
            nesting_down(common_check_named_node),
            timap(
                function(v) return "input:" .. v end,
                tijoin_many(tclone(leaf_data_types), input_node_data_types)
              )
          ),
        specialized_validators.doc
      )

    specialized_validators.output = tappend_many(
        tsetof(
            nesting_down(common_check_named_node),
            timap(
                function(v) return "output:" .. v end,
                tijoin_many(tclone(leaf_data_types), output_node_data_types)
              )
          ),
        specialized_validators.doc
      )

    specialized_validators.output_with_events = specialized_validators.output

    specialized_validators.additional_errors = tappend_many(
        tsetof(
            nesting_down(common_check_node),
            timap(
                function(v) return "err:" .. v end,
                additional_errors
              )
          ),
        specialized_validators.doc
      )

    -- TODO: Uncomment and implement!
    -- specialized_validators.tests = tests

    for k, v in pairs(specialized_validators) do
      specialized_validators[k] = init_validators_table(
          "is unexpected here",
          v
        )
    end
  end

  local validate_handler = function(
      known_exports,
      allowed_requires,
      allowed_globals,
      walkers,
      upvalues_to_be,
      data
    )
    arguments(
        "table", known_exports,
        "table", allowed_requires,
        "table", allowed_globals,
        "table", walkers,
        "table", upvalues_to_be,
        "table", data
      )

    wensure(
        walkers, data,
        "wrong handler type expected function, got",
        type(data.handler) == "function",
        type(data.handler)
      )

    local info = debug.getinfo(data.handler)
    wensure(
        walkers, data,
        "handler must be a Lua function, got",
        (info.what == "Lua"),
        type(info.what)
      )

    local data_id = tostring(data.id)
     .. (data.name and (" '" .. tostring(data.name) .. "'") or "")

    -- Validate globals
    local globals = list_globals_in_handler(
        walkers.checker_,
        data_id,
        data.handler
      )

    check_globals(
        known_exports,
        allowed_requires,
        allowed_globals,
        walkers.checker_,
        data_id,
        globals,
        upvalues_to_be
      )
  end

  local validate_doc_section = function(walkers, data)
    common_check_node(walkers, data)

    -- TODO: Check more?

    walkers.node_.have_docs = true

    return "break"
  end

  local validate_export = function(walkers, data)

    common_check_url_node(walkers, data)

    if not data.exports then
      wfail(
          walkers, data,
          "missing exports section"
        )
    end

    if not data.handler then
      wfail(
          walkers, data,
          "missing exports handler section"
        )
    end

    local upvalues_to_be = { }
    do
      -- TODO: Hack!
      upvalues_to_be["log"] = true
      upvalues_to_be["dbg"] = true
      upvalues_to_be["spam"] = true
      upvalues_to_be["log_error"] = true
    end

    validate_handler(
        walkers.known_exports_,
        walkers.allowed_requires_,
        walkers.allowed_globals_,
        walkers,
        upvalues_to_be,
        data
      )

    if not data.have_tests then -- TODO: This should be error, not warning!
      log("WARNING: Missing tests for", data.id, data.name)
    end

    if not data.have_docs then -- TODO: This should be error, not warning?
      log("WARNING: Missing docs for", data.id, data.name)
    end
  end

  local validate_extend_context = function(walkers, data)

    common_check_url_node(walkers, data)

    if not data.handler then
      wfail(
          walkers, data,
          "missing extend_context handler section"
        )
    end

    local upvalues_to_be = { }
    do
      -- TODO: Hack!
      upvalues_to_be["log"] = true
      upvalues_to_be["dbg"] = true
      upvalues_to_be["spam"] = true
      upvalues_to_be["log_error"] = true
    end

    validate_handler(
        walkers.known_exports_,
        walkers.allowed_requires_,
        walkers.allowed_globals_,
        walkers,
        upvalues_to_be,
        data
      )

    if not data.have_tests then -- TODO: This should be error, not warning!
      log("WARNING: Missing tests for", data.id, data.name)
    end

    if not data.have_docs then -- TODO: This should be error, not warning?
      log("WARNING: Missing docs for", data.id, data.name)
    end
  end

  local validate_api_section = function(walkers, data)
    common_check_node(walkers, data)

    local section = { }

    local section_name = assert(data.tag)
    if
      section_name == "handler" or
      section_name == "session_handler" or
      section_name == "client_session_handler" or
      section_name == "session_handler_with_events" or
      section_name == "dynamic_output_format_handler" or
      section_name == "raw_handler"
    then
      if walkers.found_handler_ then
        wfail(
            walkers, data,
            "more than one handler found"
          )
      end

      walkers.found_handler_ = true

      if section_name == "dynamic_output_format_handler" then
        walkers.handler_is_dynamic_ = true
        walkers.handler_is_raw_ = false
      elseif section_name == "raw_handler" then
        walkers.handler_is_raw_ = true
        walkers.handler_is_dynamic_ = false
      else
        walkers.handler_is_dynamic_ = false
        walkers.handler_is_raw_ = false
      end

      -- TODO: Fill this from top-level api:upvalue calls?
      local upvalues_to_be = { }
      do
        -- TODO: Hack!
        upvalues_to_be["log"] = true
        upvalues_to_be["dbg"] = true
        upvalues_to_be["spam"] = true
        upvalues_to_be["log_error"] = true
      end

      validate_handler(
          walkers.known_exports_,
          walkers.allowed_requires_,
          walkers.allowed_globals_,
          walkers,
          upvalues_to_be,
          data
        )
    elseif
      section_name == "error_handler" or
      section_name == "response_handler"
    then
      walkers.handler_is_dynamic_ = false
      walkers.handler_is_raw_ = false
      local upvalues_to_be = { }
      do
        -- TODO: Hack!
        upvalues_to_be["log"] = true
        upvalues_to_be["dbg"] = true
        upvalues_to_be["spam"] = true
        upvalues_to_be["log_error"] = true
      end

      validate_handler(
          walkers.known_exports_,
          walkers.allowed_requires_,
          walkers.allowed_globals_,
          walkers,
          upvalues_to_be,
          data
        )
    elseif section_name == "tests" then

      walkers.node_.have_tests = true

      -- TODO: Fill this from top-level api:upvalue calls?
      local upvalues_to_be = { }
      do
        -- TODO: Hack!
        upvalues_to_be["log"] = true
        upvalues_to_be["dbg"] = true
        upvalues_to_be["spam"] = true
        upvalues_to_be["log_error"] = true

        upvalues_to_be["test"] = true
      end

      validate_handler(
          walkers.known_exports_, -- TODO: this should be known_test_exports
          walkers.allowed_requires_,
          walkers.allowed_globals_,
          walkers,
          upvalues_to_be,
          data
        )

    elseif section_name == "dynamic_output_format" then

      --[[
      -- TODO: ?! Filter out docs if you want to re-enable this check
      if #data > 0 then
        wfail(
            walkers, data,
            "api:dynamic_output_format should be empty"
          )
      end
      --]]

    else

      local validators = specialized_validators[data.tag]
      if not validators then
        wfail(
            walkers, data,
            "unknown tag " .. data.id
          )
      end

      local deeper_walkers =
      {
        down = validators;
        up = nesting_up;
        --
        checker_ = make_checker();
        section_ = section;
        known_names_ = { };
        have_output_tag_ = false;
        root_only_first_level_tags_ = (data.id == "api:output");
        number_of_first_level_output_tags_ = 0;
        nesting_ = 0;
        --
        known_exports_ = walkers.known_exports_;
        allowed_requires_ = walkers.allowed_requires_;
        allowed_globals_ = walkers.allowed_globals_;
      }

      for i = 1, #data do
        walk_tagged_tree(data[i], deeper_walkers, "id")
      end

      if not deeper_walkers.checker_:good() then
        wfail(
            walkers, data,
            deeper_walkers.checker_:msg()
          )
      end

      if data.id == "api:output" then
        wensure(
            walkers, data,
            "must have at least one output:* defined",
            deeper_walkers.have_output_tag_
          )

        wensure(
            walkers, data,
            "must have single root tag",
            deeper_walkers.number_of_first_level_output_tags_ == 1
          )

        -- Keep this sanity check intact, it is useful.
        assert(
            deeper_walkers.nesting_ == 0,
            "bad implementation: api:output nesting is not balanced"
          )
      end
    end

    if walkers.node_[section_name] then
      wfail(
          walkers, data,
          "is duplicate"
        )
    end

    walkers.node_[section_name] = section

    return "break" -- Do not traverse deeper, we've handled everything here.
  end

  -- TODO: Validate that there is only one api:* of each kind
  --       (And only single handler of any kind)
  local api_section_validators = init_validators_table(
      "is unexpected here",
      {
        ["api:input"] = validate_api_section;
        ["api:output"] = validate_api_section;
        ["api:output_with_events"] = validate_api_section;
        ["api:dynamic_output_format"] = validate_api_section;
        ["api:additional_errors"] = validate_api_section;
        ["api:handler"] = validate_api_section;
        ["api:session_handler"] = validate_api_section;
        ["api:client_session_handler"] = validate_api_section;
        ["api:session_handler_with_events"] = validate_api_section;
        ["api:dynamic_output_format_handler"] = validate_api_section;
        ["api:error_handler"] = validate_api_section;
        ["api:response_handler"] = validate_api_section;
        ["api:raw_handler"] = validate_api_section;
        ["api:tests"] = validate_api_section;

        ["doc:description"] = validate_doc_section;
        ["doc:comment"] = validate_doc_section;
      }
    )

  local validate_api_url = function(walkers, data)
    common_check_url_node(walkers, data)

    local node = { }

    local deeper_walkers =
    {
      down = api_section_validators;
      --
      checker_ = make_checker();
      node_ = node;
      found_handler_ = false;
      handler_is_dynamic_ = false;
      handler_is_raw_ = false;
      --
      known_exports_ = walkers.known_exports_;
      allowed_requires_ = walkers.allowed_requires_;
      allowed_globals_ = walkers.allowed_globals_;
    }

    for i = 1, #data do
      walk_tagged_tree(data[i], deeper_walkers, "id")
    end

    if not deeper_walkers.checker_:good() then
      wfail(
          walkers, data,
          deeper_walkers.checker_:msg()
        )
    end

    if not node.input then
      wfail(
          walkers, data,
          "missing input section"
        )
    end

    -- TODO: Check there is exactly one output node.
    do
      local output_count = 0
      if node.output then
        output_count = output_count + 1
      end
      if node.output_with_events then
        output_count = output_count + 1
      end
      if node.dynamic_output_format then
        output_count = output_count + 1
      end

      if deeper_walkers.handler_is_raw_ then
        if output_count ~= 0 then
          wfail(
              walkers, data,
              "can't define output section for raw handler"
            )
        end

        if node.additional_errors then
          wfail(
              walkers, data,
              "can't define errors for raw handler"
            )
        end
      else
        if output_count < 1 then
          wfail(
              walkers, data,
              "missing output section"
            )
        elseif output_count > 1 then
          wfail(
              walkers, data,
              "too many output sections"
            )
        end

        if not node.additional_errors then
          wfail(
              walkers, data,
              "missing error definition section"
            )
        end
      end
    end

    if not deeper_walkers.found_handler_ then
      wfail(
          walkers, data,
          "missing handler"
        )
    end

    if
      node.dynamic_output_format
      and not deeper_walkers.handler_is_dynamic_
    then
      wfail(
          walkers, data,
          "dynamic output format requires dynamic handler"
        )
    end

    if
      deeper_walkers.handler_is_dynamic_
      and not node.dynamic_output_format
    then
      wfail(
          walkers, data,
          "dynamic handler requires dynamic output format"
        )
    end

    if
      deeper_walkers.handler_is_raw_
      and deeper_walkers.handler_is_dynamic_
    then
        wfail(
            walkers, data,
            "handler can't be both dynamic and raw"
          )
    end

    if not node.have_tests then -- TODO: This should be error, not warning!
      log("WARNING: Missing tests for", data.id, data.name)
    end

    if not node.have_docs then -- TODO: This should be error, not warning?
      log("WARNING: Missing docs for", data.id, data.name)
    end

    return "break" -- Do not traverse deeper, we've handled everything here.
  end

  -- TODO: ?! Allow all?
  local known_content_types = tset
  {
    'text/html';
    'text/xml';
    'text/plain';
    'application/javascript';
    'application/json';
    'application/octet-stream';
  }

  local validate_static_url = function(walkers, data)
    common_check_url_node(walkers, data)
    wensure(
        walkers, data,
        "static url text must be string, got",
        type(data.text) == "string",
        type(data.text)
      )
    wensure(
        walkers, data,
        "unknown content_type",
        known_content_types[data.content_type],
        tostring(data.content_type)
      )
    return "break"
  end

  local validate_doc_text = common_check_node -- TODO: Validate more?

  -- TODO: Check that all io types were mentioned!
  local validate_io_type = function(walkers, data)
    common_check_node(walkers, data)

    wensure(
        walkers, data,
        "unknown io type",
        data_type_set[data.name],
        tostring(data.name)
      )

    -- TODO: Validate more?

    return "break"
  end

  local api_validators = init_validators_table(
      "is unexpected at top-level",
      tappend_many(
          tsetof(
              validate_api_url,
              {
                "api:url";
                "api:cacheable_url";
                "api:url_with_dynamic_output_format";
                "api:raw_url";
              }
            ),
          tsetof(
              validate_static_url,
              {
                "api:static_url";
              }
            ),
          tsetof(
              validate_export,
              {
                "api:export";
              }
            ),
          tsetof(
              validate_extend_context,
              {
                "api:extend_context";
              }
            ),
          tsetof(
              validate_doc_text,
              {
                "doc:text";
              }
            ),
          tsetof(
              validate_io_type,
              {
                "io_type:enum";
                "io_type:integer";
                "io_type:string";
                "io_type:text";
                "io_type:timestamp";
              }
            )
        )
    )

  validate_schema = function(
      known_exports,
      allowed_requires,
      allowed_globals,
      api
    )
    arguments(
        "table", known_exports,
        "table", allowed_requires,
        "table", allowed_globals,
        "table", api
      )

    -- TODO: Check for duplicate urls (including aliases)

    local walkers =
    {
      down = api_validators;
      --
      checker_ = make_checker();
      known_exports_ = known_exports;
      allowed_requires_ = allowed_requires;
      allowed_globals_ = allowed_globals;
    }

    for i = 1, #api do
      log("validating", i, api[i].name)
      walk_tagged_tree(api[i], walkers, "id")
    end

    walkers.checker_:ensure("api version missing", not not api.version)

    assert(walkers.checker_:result())

    log("validation OK")
  end
end

--------------------------------------------------------------------------------

return
{
  validate_schema = validate_schema;
}
