api:export "util.common"
{
  exports =
  {
    "SOME_CONSTANT";
    --
    "some_function";
  };

  handler = function()
    local SOME_CONSTANT = "Some const string";
    local some_function = function(api_context, id)
      arguments(
          "table", api_context,
          "string", id
        )
    end
  end
}
