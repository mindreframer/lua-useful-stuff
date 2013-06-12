--------------------------------------------------------------------------------
-- request.lua: apigen stub
--------------------------------------------------------------------------------
--
-- WARNING: Run code here inside call()
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

local fail,
      try
      = import 'pk-core/error.lua'
      {
        'fail',
        'try'
      }

local make_loggers
      = import 'pk-core/log.lua'
      {
        'make_loggers'
      }

--------------------------------------------------------------------------------

local log, dbg, spam, log_error = make_loggers("webservice/request", "WRQ")

--------------------------------------------------------------------------------

local WWW_ADMIN_CONFIG_SECTION = "#{UNDERLINE(PROJECT_NAME)}"
local WWW_APPLICATION_CONFIG_SECTION = "#{UNDERLINE(PROJECT_NAME)}"

-- TODO: Maybe get rid of it?
local get_www_admin_config = function(context)
  local config, err = context.config_manager:get_www_admin_info(
      WWW_ADMIN_CONFIG_SECTION
    )
  if not config then
    log_error(
        "failed to get www/admin config for",
        WWW_ADMIN_CONFIG_SECTION,
        err
      )
    return nil, err
  end
  return config
end

-- TODO: Move to a more appropriate place?
-- TODO: this is "get_www_application_config", name left for compatibility
local get_www_game_config = function(context)
  local config, err = context.config_manager:get_www_application_info(
      WWW_APPLICATION_CONFIG_SECTION
    )
  if not config then
    log_error(
        "failed to get www/application config for",
        WWW_APPLICATION_CONFIG_SECTION,
        err
      )
    return nil, err
  end
  return config
end

--------------------------------------------------------------------------------

return
{
  WWW_APPLICATION_CONFIG_SECTION = WWW_APPLICATION_CONFIG_SECTION;
  --
  get_www_game_config = get_www_game_config;
  get_www_admin_config = get_www_admin_config;
}
