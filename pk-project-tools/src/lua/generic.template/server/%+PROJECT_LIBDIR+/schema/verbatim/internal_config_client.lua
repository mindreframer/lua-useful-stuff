--------------------------------------------------------------------------------
-- internal_config_client.lua: internal config server client
--------------------------------------------------------------------------------

local pairs = pairs
local math_random = math.random

--------------------------------------------------------------------------------

local arguments,
      method_arguments,
      optional_arguments
      = import 'lua-nucleo/args.lua'
      {
        'arguments',
        'method_arguments',
        'optional_arguments'
      }

local is_string
      = import 'lua-nucleo/type.lua'
      {
        'is_string'
      }

local invariant
      = import 'lua-nucleo/functional.lua'
      {
        'invariant'
      }

local dostring_in_environment
      = import 'lua-nucleo/sandbox.lua'
      {
        'dostring_in_environment'
      }

local make_loggers
      = import 'pk-core/log.lua'
      {
        'make_loggers'
      }

local http_request
      = import 'pk-engine/connector.lua'
      {
        'http_request'
      }

--------------------------------------------------------------------------------

local log, dbg, spam, log_error = make_loggers("internal_config/client", "ICC")

--------------------------------------------------------------------------------

local CHANNEL_NODES_URL         = "/cfg/channels/nodes"
local CHANNEL_NAMES_URL         = "/cfg/channels/names"
local HEARTBEAT_NODES_URL       = "/cfg/heartbeat/nodes"
local DICTIONARY_NODES_URL      = "/cfg/dictionary/nodes"
local TASK_PROCESSOR_NODES_URL  = "/cfg/task/nodes"
local TASK_PROCESSOR_GROUPS_URL = "/cfg/task/groups"
local CRONTAB_URL               = "/cfg/cron/crontab"
local CRON_GROUPS_URL           = "/cfg/cron/groups"
local DB_INFO_URL               = "/cfg/db/bases"
local WWW_APPLICATION_INFO_URL  = "/cfg/www/application/config"
local WWW_ADMIN_INFO_URL        = "/cfg/www/admin/config"
local REDIS_NODES_URL           = "/cfg/redis/nodes"
local SERVICES_CONFIG_URL       = "/cfg/services/config"

--------------------------------------------------------------------------------

local make_config_manager
do
  local CHANNEL_NODE_LIST         = "channel_nodes_"
  local HEARTBEAT_NODE_LIST       = "heartbeat_nodes_"
  local DICTIONARY_NODE_LIST      = "dictionary_nodes_"
  local TASK_PROCESSOR_NODE_LIST  = "task_processor_nodes_"
  local TASK_PROCESSOR_GROUP_LIST = "task_processor_groups_"
  local DB_INFO_LIST              = "db_info_"
  local WWW_APPLICATION_INFO_LIST = "www_application_info_"
  local WWW_ADMIN_INFO_LIST       = "www_admin_info_"
  local REDIS_NODE_LIST           = "redis_nodes_"
  local SERVICES_CONFIG_LIST      = "services_config_"

  local CRON_GROUP_LIST = "cron_groups_"
  local CRONTAB = "crontab"

  local load_section = function(host, port, section_name)
    local url = "http://"..host..":"..port..section_name
    local code, err = http_request(url)
    if not code then
      log_error("failed to load internal config section from", url, ":", err)
      return nil, "load_section failed: " .. tostring(err)
    end

    -- spam("fetched", code)

    local env = { }

    local res, data = dostring_in_environment(code, env, "@"..section_name)
    if not res then
      err = data
      log_error(
          "failed to load config code for section", section_name, ":", err
        )
      return nil, "load_section failed: " .. tostring(err)
    end

    -- TODO: Validate and sanitize data!!!

    return env
  end

  local load_channel_matcher
  do
    local make_channel_matcher
    do
      local match = function(self, channel_name)
        method_arguments(
            self,
            "string", channel_name
          )

        -- TODO: Shouldn't it be some fancy lua-nucleo call?
        local matchers = self.matchers_

        local direct_matcher = matchers[channel_name]
        if direct_matcher then
          local server = direct_matcher()
          --dbg("direct match", channel_name, "=>", server)
          return server
        end

        for i = 1, #matchers do
          local server = matchers[i](channel_name)
          if server then
            --dbg("indirect match by rule", i, channel_name, "=>", server)
            return server
          end
        end

        return nil
      end

      local load_matchers
      do
        local make_fixed_matcher = function(server_names)
          arguments(
              "table", server_names
            )

          local num_servers = #server_names
          if num_servers == 1 then
            return invariant(server_names[1])
          else
            return function()
              return server_names[math_random(num_servers)]
            end
          end
        end

        local make_regexp_matcher = function(channel_regexp, server_names)
          arguments(
              "string", channel_regexp,
              "table", server_names
            )

          -- TODO: Create this on demand only?
          local fixed_matcher = make_fixed_matcher(server_names)

          return function(channel_name)
            arguments(
                "string", channel_name
              )

            --spam("regexp_matcher channel_name:find", channel_regexp, channel_name)

            if channel_name:find(channel_regexp) then
              return fixed_matcher()
            end

            return nil
          end
        end

        load_matchers = function(code)
          arguments(
              "string", code
            )

          local matchers = { }

          local env = setmetatable(
              { },
              {
                __metatable = true;
                __index =
                {
                  match = function(channel, server_names)
                    if is_string(server_names) then
                      server_names = { server_names }
                    end

                    arguments(
                        "string", channel,
                        "table", server_names
                      )

                    if matchers[channel] then
                      error(
                          "attempted to override rule for channel `"..channel.."'"
                        )
                    end

                    matchers[channel] = make_fixed_matcher(server_names)
                  end;

                  match_regexp = function(channel_regexp, server_names)
                    if is_string(server_names) then
                      server_names = { server_names }
                    end

                    -- TODO: Regexp MUST be filtered
                    --       to avoid CPU and memory consumption attacks!
                    arguments(
                        "string", channel_regexp,
                        "table", server_names
                      )

                    matchers[#matchers + 1] = make_regexp_matcher(
                        channel_regexp,
                        server_names
                      )
                  end;
                };
              }
            )

          local res, data = dostring_in_environment(
              code,
              env,
              "@"..CHANNEL_NAMES_URL
            )
          if not res then
            local err = data
            log_error("failed to load matchers:", err)
            return nil, "load_matchers failed: " .. tostring(err)
          end

          return matchers
        end
      end

      make_channel_matcher = function(code)
        local matchers, err = load_matchers(code)
        if not matchers then
          log_error("failed to make channel matcher:", err)
          return nil, "make_channel_matcher failed:" .. tostring(err)
        end

        return
        {
          match = match;
          --
          matchers_ = matchers;
        }
      end
    end

    load_channel_matcher = function(host, port)
      local url = "http://"..host..":"..port..CHANNEL_NAMES_URL
      local code, err = http_request(url)
      if not code then
        log_error("failed to load channel matcher from", url, ":", err)
        return nil, "load_channel_matcher failed:" .. tostring(err)
      end

      local channel_matcher

      channel_matcher, err = make_channel_matcher(code)

      if not channel_matcher then
        log_error("failed to load channel matcher from", url, ":", err)
        return nil, "load_channel_matcher failed: " .. tostring(err)
      end

      return channel_matcher
    end
  end

  -- Private function
  local get_node_info = function(self, list_name, list_elem_name, list_url)
    method_arguments(
        self,
        "string", list_name,
        "string", list_elem_name,
        "string", list_url
      )

    if self[list_name] == nil then
      local err

      -- Note: connection is not shared because data is cached
      --       and reconnections should be rare.
      self[list_name], err = load_section(self.host_, self.port_, list_url)
      if not self[list_name] then
        log_error(
            "failed top load node info section",
            self.host_, self.port_, list_url, ":", err
          )
        return nil, "get_node_info failed: " .. tostring(err)
      end
    end

    local data = self[list_name][list_elem_name]
    if data then
      return data
    end

    return nil, "can't find element `" .. list_elem_name .. "' of list `" .. list_name .. "'"
  end

  local get_channel_node_info = function(self, node_name)
    method_arguments(self, "string", node_name)
    return get_node_info(self, CHANNEL_NODE_LIST, node_name, CHANNEL_NODES_URL)
  end

  -- TODO: Generalize with get_channel_node_info
  local get_channel_server = function(self, channel_name)
    method_arguments(
        self,
        "string", channel_name
      )

    if self.channel_matcher_ == nil then
      local err

      -- Note: connection is not shared because data is cached
      --       and reconnections should be rare.
      self.channel_matcher_, err = load_channel_matcher(self.host_, self.port_)

      if not self.channel_matcher_ then
        log_error(
            "failed to load channel matcher from", self.host_, self.port_,
            ":", err
          )
        return nil, "get_channel_server failed:" .. tostring(err)
      end
    end

    local channel_info = self.channel_matcher_:match(channel_name)
    if channel_info then
      return channel_info
    end

    return nil, "can't match server for channel `"..channel_name.."'"
  end

  local get_heartbeat_node_info = function(self, node_name)
    method_arguments(self, "string", node_name)
    return get_node_info(self, HEARTBEAT_NODE_LIST, node_name, HEARTBEAT_NODES_URL)
  end

  local get_dictionary_node_info = function(self, node_name)
    method_arguments(self, "string", node_name)
    return get_node_info(self, DICTIONARY_NODE_LIST, node_name, DICTIONARY_NODES_URL)
  end

  local get_task_node_info = function(self, node_name)
    method_arguments(self, "string", node_name)
    return get_node_info(self, TASK_PROCESSOR_NODE_LIST, node_name, TASK_PROCESSOR_NODES_URL)
  end

  local get_task_group_info = function(self, group_name)
    method_arguments(self, "string", group_name)
    return get_node_info(self, TASK_PROCESSOR_GROUP_LIST, group_name, TASK_PROCESSOR_GROUPS_URL)
  end

  local get_db_info = function(self, group_name)
    method_arguments(self, "string", group_name)
    return get_node_info(self, DB_INFO_LIST, group_name, DB_INFO_URL)
  end

  local get_www_application_info = function(self, group_name)
    method_arguments(self, "string", group_name)
    return get_node_info(self, WWW_APPLICATION_INFO_LIST, group_name, WWW_APPLICATION_INFO_URL)
  end

  local get_www_admin_info = function(self, group_name)
    method_arguments(self, "string", group_name)
    return get_node_info(self, WWW_ADMIN_INFO_LIST, group_name, WWW_ADMIN_INFO_URL)
  end

  local get_redis_node_info = function(self, node_name)
    method_arguments(self, "string", node_name)
    return get_node_info(self, REDIS_NODE_LIST, node_name, REDIS_NODES_URL)
  end

  local get_services_config = function(self, node_name)
    method_arguments(self, "string", node_name)
    return get_node_info(self, SERVICES_CONFIG_LIST, node_name, SERVICES_CONFIG_URL)
  end

  local get_task_group_channel = function(self, group_name)
    method_arguments(
        self,
        "string", group_name
      )

    local group, err = self:get_task_group_info(group_name)
    if not group then
      log_error("failed to get task group info for", group_name, ":", err)
      return nil, "get_task_group_channel failed: " .. tostring(err)
    end

    return group.channel
  end

  local get_cron_group_info = function(self, group_name)
    method_arguments(self, "string", group_name)
    return get_node_info(self, CRON_GROUP_LIST, group_name, CRON_GROUPS_URL)
  end

  local get_crontab = function(self)
    method_arguments(
        self
      )

    if self[CRONTAB] == nil then
      local err

      -- Note: connection is not shared because data is cached
      --       and reconnections should be rare.
      self[CRONTAB], err = load_section(self.host_, self.port_, CRONTAB_URL)
      if not self[CRONTAB] then
        log_error(
            "failed to load crontab section from",
            self.host_, self.port_, CRONTAB_URL, ":", err
          )
        return nil, "get_crontab failed: " .. tostring(err)
      end
    end

    return self[CRONTAB]
  end

  make_config_manager = function(host, port)
    arguments(
        "string", host,
        "number", port
      )

    return
    {
      get_channel_node_info = get_channel_node_info;
      get_channel_server = get_channel_server;
      get_heartbeat_node_info = get_heartbeat_node_info;
      get_dictionary_node_info = get_dictionary_node_info;
      get_task_node_info = get_task_node_info;
      get_task_group_info = get_task_group_info;
      get_task_group_channel = get_task_group_channel;
      get_cron_group_info = get_cron_group_info;
      get_crontab = get_crontab;
      get_db_info = get_db_info;
      get_www_application_info = get_www_application_info;
      get_www_admin_info = get_www_admin_info;
      get_redis_node_info = get_redis_node_info;
      get_services_config = get_services_config;
      --
      host_ = host;
      port_ = port;
      --
      channel_matcher_ = nil;
      --
      [CHANNEL_NODE_LIST] = nil;
      [HEARTBEAT_NODE_LIST] = nil;
      [DICTIONARY_NODE_LIST] = nil;
      [TASK_PROCESSOR_NODE_LIST] = nil;
      [TASK_PROCESSOR_GROUP_LIST] = nil;
      [DB_INFO_LIST] = nil;
      [WWW_APPLICATION_INFO_LIST] = nil;
      [WWW_ADMIN_INFO_LIST] = nil;
      [REDIS_NODE_LIST] = nil;
      [SERVICES_CONFIG_LIST] = nil;
      [CRONTAB] = nil;
    }
  end
end

--------------------------------------------------------------------------------

return
{
  CHANNEL_NODES_URL = CHANNEL_NODES_URL;
  CHANNEL_NAMES_URL = CHANNEL_NAMES_URL;
  HEARTBEAT_NODES_URL = HEARTBEAT_NODES_URL;
  DICTIONARY_NODES_URL = DICTIONARY_NODES_URL;
  TASK_PROCESSOR_NODES_URL = TASK_PROCESSOR_NODES_URL;
  TASK_PROCESSOR_GROUPS_URL = TASK_PROCESSOR_GROUPS_URL;
  CRONTAB_URL = CRONTAB_URL;
  CRON_GROUPS_URL = CRON_GROUPS_URL;
  DB_INFO_URL = DB_INFO_URL;
  WWW_APPLICATION_INFO_URL = WWW_APPLICATION_INFO_URL;
  WWW_ADMIN_INFO_URL = WWW_ADMIN_INFO_URL;
  REDIS_NODES_URL = REDIS_NODES_URL;
  SERVICES_CONFIG_URL = SERVICES_CONFIG_URL;
  --
  make_config_manager = make_config_manager;
}
