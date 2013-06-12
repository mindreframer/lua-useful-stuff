--------------------------------------------------------------------------------
-- settings.lua
-- This file is a part of pk-billing-lib library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------

api:export "lib/settings"
{
  exports =
  {
    --data
    "APP_FIELDS_LIST";
    "PAYSYSTEMS_FIELDS_LIST";
    "SUBPAYSYSTEMS_FIELDS_LIST";

    "APPS_LIST";
    "PAYSYSTEMS_LIST";

    --methods
  };

  handler = function()
    local PAYSYSTEMS_FIELDS_LIST = { "id", "title", "create_form_script", "config" }
    local OPTIONAL_PAYSYSTEMS_FIELDS = tset { "create_form_script" }
    local SUBPAYSYSTEMS_FIELDS_LIST = { "id", "title" }
    local APP_FIELDS_LIST = { "id", "title", "api_url" , "api_format" , "config"}

    local APPS_LIST = "applications"
    local PAYSYSTEMS_LIST = "paysystems"
  end;
}

api:extend_context "settings.cache" (function()
------------------------------- PAYSYSTEMS ----------------------------------------
  local paysystem_config_serialized_fields = { "config",  "subpaysystems" }

  local try_get_paysystem = function(self, api_context, paysystem_id, field)
    method_arguments(
        self,
        "table", api_context,
        "string", paysystem_id
      )

    local cache = api_context:hiredis():settings()
    local paysystem_id = tostring(paysystem_id)
    local start = paysystem_id:find("paysystem:")
    if start == nil then
      paysystem_id = "paysystem:" .. paysystem_id
    end

    local result = { }
    if field ~= nil then
      result = try_unwrap(
          "INTERNAL_ERROR",
          cache:command("HGET", paysystem_id, field)
        )
      if type(result) == table then
        result = nil
      end
    else
      result = try_unwrap(
          "INTERNAL_ERROR",
          cache:command("HGETALL", paysystem_id)
        )
    end

    if result == nil or #result == 0 then
      return fail("PAYSYSTEM_NOT_FOUND", "Paysystem '" .. paysystem_id .. "' not found")
    end

    result = tkvlist2kvpairs(result)

    for i = 1, #paysystem_config_serialized_fields do
      local serialized_field = paysystem_config_serialized_fields[i]
      if result[serialized_field] then
        local res, value = try("INTERNAL_ERROR", luabins.load(result[serialized_field]))
        result[serialized_field] = value
      end
    end
    api_context.paysystem_schema = api_context.paysystem_schema or create_paysystem_schema()

    return try(
        "INTERNAL_ERROR",
        load_config(api_context.paysystem_schema, result)
      )
  end

  local try_get_paysystems = function(self, api_context)
    method_arguments(
        self,
        "table", api_context
      )
    local cache = api_context:hiredis():settings()

    local paysystems_ids = try_unwrap(
        "INTERNAL_ERROR",
        cache:command("SMEMBERS", PAYSYSTEMS_LIST)
      )

    local paysystems = { }
    for i = 1, #paysystems_ids do
      paysystems[#paysystems + 1] = api_context:ext("settings.cache"):try_get_paysystem(api_context, paysystems_ids[i])
    end

    return paysystems
  end

  local try_set_paysystem = function(self, api_context, paysystem)
    method_arguments(
        self,
        "table", api_context,
        "table", paysystem
      )

    api_context.paysystem_schema = api_context.paysystem_schema or create_paysystem_schema()
    local paysystem = try(
        "INTERNAL_ERROR",
        load_config(api_context.paysystem_schema, paysystem)
      )

    local commands_count = 0
    local cache = api_context:hiredis():settings()

    try_unwrap(
        "INTERNAL_ERROR",
        cache:append_command("SADD", PAYSYSTEMS_LIST, paysystem.id)
      )
    commands_count = commands_count + 1
    local paysystem_id = "paysystem:" .. paysystem.id

    for i = 1, #paysystem_config_serialized_fields do
      local serialized_field = paysystem_config_serialized_fields[i]
      local table_to_serialize = { }
        for k, v in pairs(paysystem[serialized_field]) do
          table_to_serialize[k] = v
        end
        paysystem[serialized_field] = try(
            "INTERNAL_ERROR",
            luabins.save(table_to_serialize)
          )
    end

    for key, value in pairs(paysystem) do
      try_unwrap(
          "INTERNAL_ERROR",
          cache:append_command("HMSET", paysystem_id, key, value)
        )
      commands_count = commands_count + 1
    end

    for i = 1, commands_count do
      try_unwrap("INTERNAL_ERROR", cache:get_reply()) -- hmset
    end
  end

------------------------------- APPLICATIONS ----------------------------------------
  local app_config_serialized_fields = { "config", "api" }

  local try_get_app = function(self, api_context, application_id, field)
    method_arguments(
        self,
        "table", api_context,
        "string", application_id
      )

    local cache = api_context:hiredis():settings()

    if self.applications_[application_id] ~= nil then
      return self.applications_[application_id]
    end

    local start = application_id:find("application:")
    if start == nil then
      application_id = "application:" .. application_id
    end

    local result = { }
    if field ~= nil then
      result = try_unwrap(
          "INTERNAL_ERROR",
          cache:command("HGET", application_id, field)
        )
      if result == hiredis.NIL then
        result = nil
      end
    else
      result = try_unwrap(
          "INTERNAL_ERROR",
          cache:command("HGETALL", application_id)
        )
    end

    if not is_table(result) or #result == 0 then
      return fail("APPLICATION_NOT_FOUND", "Application '" .. application_id .. "' not found")
    end
    result = tkvlist2kvpairs(result)

    for i = 1, #app_config_serialized_fields do
      local serialized_field = app_config_serialized_fields[i]
      if result[serialized_field] then
        local res, value = try("INTERNAL_ERROR", luabins.load(result[serialized_field]))
        result[serialized_field] = value
      end
    end
    api_context.app_config_schema = api_context.app_config_schema or create_application_config_schema()
    local app = try(
        "INTERNAL_ERROR",
        load_config(api_context.app_config_schema, result)
      )
    self.applications_[application_id] = app
    return app
  end

  local try_get_apps = function(self, api_context)
    method_arguments(
        self,
        "table", api_context
      )
    local cache = api_context:hiredis():settings()

    local app_ids = try_unwrap(
        "INTERNAL_ERROR",
        cache:command("SMEMBERS", APPS_LIST)
      )

    local apps = { }
    for i = 1, #app_ids do
      apps[#apps + 1] = api_context:ext("settings.cache"):try_get_app(api_context, app_ids[i])
    end

    return apps
  end

  local try_set_app = function(self, api_context, application)
    method_arguments(
        self,
        "table", api_context,
        "table", application
      )

    api_context.app_config_schema = api_context.app_config_schema or create_application_config_schema()
    local application = try(
        "INTERNAL_ERROR",
        load_config(api_context.app_config_schema, application)
      )
    local application_id = "application:" .. application.id

    local cache = api_context:hiredis():settings()

    for i = 1, #app_config_serialized_fields do
      local serialized_field = app_config_serialized_fields[i]
      local table_to_serialize = { }
      for k, v in pairs(application[serialized_field]) do
        table_to_serialize[k] = v
      end
      application[serialized_field] = try(
          "INTERNAL_ERROR",
          luabins.save(table_to_serialize)
        )
    end

    for key, value in pairs(application) do
      try_unwrap(
          "INTERNAL_ERROR",
          cache:append_command("HMSET", application_id, key, value)
        )
    end
    try_unwrap(
        "INTERNAL_ERROR",
        cache:append_command("SADD", APPS_LIST, application.id)
      )

    for key, value in pairs(application) do
      try_unwrap("INTERNAL_ERROR", cache:get_reply()) -- hmset
    end
    try_unwrap("INTERNAL_ERROR", cache:get_reply()) -- hmset
  end

  local factory = function()

    return
    {
      try_get_app = try_get_app;
      try_get_apps = try_get_apps;
      try_set_app = try_set_app;
      try_get_paysystem = try_get_paysystem;
      try_get_paysystems = try_get_paysystems;
      try_set_paysystem = try_set_paysystem;

      -- private fields
      applications_ = {};
    }
  end

  -- TODO: its not work in standalone-services becuase they dont support zmq.
  -- https://redmine.iphonestudio.ru/issues/1472
  local system_action_handlers =
  {
    ["settings.cache:set_paysystem"] = function(api_context, paysystem)
      spam("settings.cache:set_paysystem")

      -- TODO: LAZY HACK. This currently updates redis data
      --       once for each fork. It should do it once per save!
      api_context:ext("settings.cache"):try_set_paysystem(api_context, paysystem)

      spam("/settings.cache")

      return true
    end;
    ["settings.cache:set_app"] = function(api_context, application)
      spam("settings.cache:set_app")

      -- TODO: LAZY HACK. This currently updates redis data
      --       once for each fork. It should do it once per save!
      api_context:ext("settings.cache"):try_set_app(api_context, application)

      spam("/settings.cache")

      return true
    end;
  }

  return
  {
    factory = factory;
    system_action_handlers = system_action_handlers;
  }
end)
