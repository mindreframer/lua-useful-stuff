--------------------------------------------------------------------------------
-- service_extensions.lua
-- This file is a part of pk-billing-lib library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------

api:export "lib/service_extensions"
{
  exports =
  {
    "INTERNAL_CALL_HANDLERS";
    "load_service_extensions";
  };

  handler = function()
    local NODE_ID = nil
    local SYSTEM_ACTION_SERVICE_NAME = nil
    local INTERNAL_CALL_HANDLERS = { }

    local request_manager = nil

    local TABLES = { }

    local ZMQ_CONTEXT = nil
    local ZMQ_CONTROL_SOCKET_URL = ""

    local get_www_admin_config = function() end
    local get_www_game_config = function() end
    local SYSTEM_ACTIONS = { }

    local URL_HANDLER_WRAPPER = make_url_handler_wrapper(
        TABLES,
        get_www_game_config,
        get_www_admin_config,
        { }, --make_output_format_manager
        INTERNAL_CALL_HANDLERS
      )

    -- TODO: Get rid of these variables in wsapi_env.
    local make_stub_wsapi_env = function()
    end

    local api_context_wrap = function(fn)
      arguments(
          "function", fn
        )

      return function(
          request_manager,
          wsapi_env,
          ...
        )
        arguments(
            "table", request_manager,
            "table", wsapi_env
          )

        return URL_HANDLER_WRAPPER:do_with_api_context(
            request_manager:get_context(wsapi_env), fn, ...
          )
      end
    end

    -------------------------------------------------------------------------------

    local load_service_extensions
    do
      load_service_extensions = function(
          request_manager_,
          wsapi_env,
          service_name,
          node_id,
          pid,
          extensions,
          system_actions,
          get_www_admin_config_,
          get_www_game_config_,
          TABLES_
        )
        load_service_extensions = do_nothing

        NODE_ID = node_id
        SYSTEM_ACTION_SERVICE_NAME = service_name
        request_manager = request_manager_
        SYSTEM_ACTIONS = system_actions
        get_www_admin_config = get_www_admin_config_
        get_www_game_config = get_www_game_config_
        TABLES = TABLES_

        local to_precache = { }

        for i = 1, #extensions do
          local ext_info = extensions[i]

          local ext_data = import(ext_info[1]) ()

          request_manager:extend_context(
              wsapi_env,
              ext_info.name,
              assert(ext_data.factory)
            )

          if ext_data.PRECACHE then
            to_precache[#to_precache + 1] = ext_info.name
          end

          if ext_data.system_action_handlers then
            for k, v in pairs(ext_data.system_action_handlers) do
              assert(
                  not SYSTEM_ACTIONS[k],
                  "duplicate system action handler"
                )
              local handler = api_context_wrap(assert_is_function(v))
              SYSTEM_ACTIONS[k] = function(...)
                return handler(
                    request_manager, make_stub_wsapi_env(), ...
                  )
              end
            end
          end
        end

        -- Doing in a second loop to help resolve interdependencies.
        for i = 1, #to_precache do
          assert(request_manager:get_context_extension(wsapi_env, to_precache[i]))
        end
      end
    end

  end;
}
