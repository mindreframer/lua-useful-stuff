--------------------------------------------------------------------------------
-- config.lua: list-exports configuration
-- This file is a part of Lua-Aplicado library
-- Copyright (c) Lua-Aplicado authors (see file `COPYRIGHT` for the license)
--------------------------------------------------------------------------------
-- Note that PROJECT_PATH is defined in the environment
--------------------------------------------------------------------------------

common =
{
  PROJECT_PATH = PROJECT_PATH;

  exports =
  {
    exports_dir = PROJECT_PATH .. "/lua-aplicado/code/";
    profiles_dir = PROJECT_PATH .. "/lua-aplicado/code/";

    sources =
    {
      {
        sources_dir = PROJECT_PATH;
        root_dir_only = "lua-aplicado/";
        lib_name = "lua-aplicado";
        profile_filename = "profile.lua";
        out_filename = "exports.lua";
        file_header = [[
-- This file is a part of lua-aplicado library
-- See file `COPYRIGHT` for the license and copyright information
]]
      };
    };
  };
}

--------------------------------------------------------------------------------

list_exports =
{
  action =
  {
    name = "help";
    param =
    {
      -- No parameters
    };
  };
};
