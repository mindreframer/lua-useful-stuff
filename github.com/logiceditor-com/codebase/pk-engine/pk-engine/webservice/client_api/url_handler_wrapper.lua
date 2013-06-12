--------------------------------------------------------------------------------
-- url_handler_wrapper.lua: api url handler wrapper
-- This file is a part of pk-engine library
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
        'method_arguments'
      }

local common_html_error,
      html_response
      = import 'pk-engine/webservice/response.lua'
      {
        'common_html_error',
        'html_response'
      }

local make_loggers
      = import 'pk-core/log.lua'
      {
        'make_loggers'
      }

local call
      = import 'pk-core/error.lua'
      {
        'call'
      }

local make_api_context
      = import 'pk-engine/webservice/client_api/api_context.lua'
      {
        'make_api_context'
      }

--------------------------------------------------------------------------------

local log, dbg, spam, log_error = make_loggers("webservice/client_api/url_handler_wrapper", "UHW")

--------------------------------------------------------------------------------

local make_url_handler_wrapper
do

  -- Common functions ----------------------------------------------------------

  local respond_and_clean_context = function(
      api_context,
      err_info,
      response_fn,
      error_formatter_fn
    )
    local err, msg = call(
        error_formatter_fn,
        tostring(err_info) or "(error message is not a string)",
        api_context
      )
    api_context:destroy()
    api_context = nil
    if not err then
      local message =
        "Error in error handler: "
     .. (tostring(msg) or "(error message is not a string)")
      log_error(message)
      error(message)
    end
    return call(response_fn, err, msg)
  end

  -- static --------------------------------------------------------------------

  local static = function(self, handler_filename)
    method_arguments(
        self,
        "string", handler_filename
      )

    -- TODO: No need to load this as a Lua file!
    -- TODO: Support other content types
    local BODY, CONTENT_TYPE
          = import (handler_filename) { 'BODY', 'CONTENT_TYPE' }

    return function(context)
      return 200, BODY, CONTENT_TYPE
    end
  end

  -- api -----------------------------------------------------------------------

  local api = function(
      self,
      handler_fn,
      input_loader,
      output_renderer,
      response_fn,
      error_formatter_fn
    )
    method_arguments(
        self,
        "function", handler_fn,
        "function", input_loader,
        "function", output_renderer,
        "function", response_fn,
        "function", error_formatter_fn
      )

    local db_tables = self.db_tables_
    local www_game_config_getter = self.www_game_config_getter_
    local www_admin_config_getter = self.www_admin_config_getter_
    local internal_call_handlers = self.internal_call_handlers_

    return function(context)
      local api_context = make_api_context(
          context,
          db_tables,
          www_game_config_getter,
          www_admin_config_getter,
          internal_call_handlers
        )

      local input, err = call(input_loader, api_context)
      if not input then
        return respond_and_clean_context(api_context, err, response_fn, error_formatter_fn)
      end

      -- TODO: HACK! Remove that "extra".
      local output, extra = call(handler_fn, api_context, input)
      if not output then
        local err = extra
        return respond_and_clean_context(api_context, err, response_fn, error_formatter_fn)
      end

      local rendered_output, err = call(
          output_renderer,
          api_context,
          output,
          extra
        )
      if not rendered_output then
        return respond_and_clean_context(api_context, err, response_fn, error_formatter_fn)
      end

      api_context:destroy()
      api_context = nil

      return response_fn(rendered_output)
    end
  end

  -- api with dynamic output format --------------------------------------------
  -- TODO: Generalize with above.
  local api_with_dynamic_output_format = function(
      self,
      handler_fn,
      input_loader,
      output_builder_factory,
      response_fn,
      error_formatter_fn
    )
    method_arguments(
        self,
        "function", handler_fn,
        "function", input_loader,
        "function", output_builder_factory,
        "function", response_fn,
        "function", error_formatter_fn
      )

    local db_tables = self.db_tables_
    local www_game_config_getter = self.www_game_config_getter_
    local www_admin_config_getter = self.www_admin_config_getter_
    local output_format_manager = self.output_format_manager_
    local internal_call_handlers = self.internal_call_handlers_

    return function(context)
      local api_context = make_api_context(
          context,
          db_tables,
          www_game_config_getter,
          www_admin_config_getter,
          internal_call_handlers
        )

      local input, err = call(input_loader, api_context)
      if not input then
        return respond_and_clean_context(api_context, err, response_fn, error_formatter_fn)
      end

      local rendered_output, err = call(
          handler_fn,
          output_format_manager,
          output_builder_factory(), -- TODO: Cache?
          api_context,
          input
        )
      if not rendered_output then
        return respond_and_clean_context(api_context, err, response_fn, error_formatter_fn)
      end

      api_context:destroy()
      api_context = nil

      return response_fn(rendered_output)
    end
  end

  -- do with api context -------------------------------------------------------

  local do_with_api_context
  do
    local destroy_context = function(api_context, ...)
      api_context:destroy()
      return ...
    end

    do_with_api_context = function(
        self, context, handler_fn, ...
      )
      method_arguments(
          self,
          "table", context,
          "function", handler_fn
        )

      local api_context = make_api_context(
          context,
          self.db_tables_,
          self.www_game_config_getter_,
          self.www_admin_config_getter_,
          self.internal_call_handlers_
        )

      return destroy_context(
          api_context,
          call(
              handler_fn,
              api_context,
              ...
            )
        )
    end
  end

  -- raw -----------------------------------------------------------------------
  -- TODO: Generalize with above.
  local raw = function(
      self,
      handler_fn,
      input_loader,
      response_handler,
      error_handler
    )
    method_arguments(
        self,
        "function", handler_fn,
        "function", input_loader
      )

    local db_tables = self.db_tables_
    local www_game_config_getter = self.www_game_config_getter_
    local www_admin_config_getter = self.www_admin_config_getter_
    local internal_call_handlers = self.internal_call_handlers_

    local raw_response_handler = response_handler or html_response
    local raw_error_handler = error_handler or common_html_error

    return function(context)
      local api_context = make_api_context(
          context,
          db_tables,
          www_game_config_getter,
          www_admin_config_getter,
          internal_call_handlers
        )

      local input, err = call(input_loader, api_context)
      if not input then
        return respond_and_clean_context(
            api_context,
            err,
            raw_response_handler,
            raw_error_handler)
      end

      local status, body, headers = call(
          handler_fn,
          api_context,
          input
        )
      if not status then
        local err = body
        return respond_and_clean_context(
            api_context,
            err,
            raw_response_handler,
            raw_error_handler)
      end

      api_context:destroy()
      api_context = nil

      return status, body, headers
    end
  end

  -- internal call -------------------------------------------------------------
  -- TODO: Generalize with above.
  -- WARNING: This works only with uhw:api() due to return value protocol!
  local internal_call = function(
      self,
      handler_fn,
      input_loader
    )
    method_arguments(
        self,
        "function", handler_fn,
        "function", input_loader
      )

    return function(api_context, param)
      arguments(
          "table", api_context, -- Note it is api_context, not merely context
          "string", param -- TODO: handle table parameters
        )

      api_context:push_param(param)

      local input, err = call(input_loader, api_context)
      if not input then
        api_context:pop_param()
        return nil, "failed to load input", err
      end

      local output, err = call(handler_fn, api_context, input)
      if not output then
        api_context:pop_param()
        return nil, "handler failed", err
      end

      api_context:pop_param()

      return output
    end
  end

  --make_url_handler_wrapper----------------------------------------------------

  make_url_handler_wrapper = function(
      db_tables,
      www_game_config_getter,
      www_admin_config_getter,
      output_format_manager,
      internal_call_handlers
    )
    arguments(
        "table", db_tables,
        "function", www_game_config_getter,
        "function", www_admin_config_getter,
        "table", output_format_manager,
        "table", internal_call_handlers
      )

    return
    {
      static = static;
      api = api;
      api_with_dynamic_output_format = api_with_dynamic_output_format;
      raw = raw;
      --
      internal_call = internal_call;
      --
      do_with_api_context = do_with_api_context;
      --
      db_tables_ = db_tables;
      www_game_config_getter_ = www_game_config_getter;
      www_admin_config_getter_ = www_admin_config_getter;
      output_format_manager_ = output_format_manager;
      internal_call_handlers_ = internal_call_handlers;
    }
  end
end

--------------------------------------------------------------------------------

return
{
  make_url_handler_wrapper = make_url_handler_wrapper;
}
