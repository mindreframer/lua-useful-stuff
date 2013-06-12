api:extend_context "example" (function()
  local try_get = function(self, api_context)
    method_arguments(
        self,
        "table", api_context
      )
    local result = { }
    return result
  end

  local try_set = function(self, api_context)
    method_arguments(
        self,
        "table", api_context
      )
  end

  local factory = function()
    return
    {
      try_get = try_get;
      try_set = try_set;
    }
  end

  return
  {
    factory = factory;
  }
end)
