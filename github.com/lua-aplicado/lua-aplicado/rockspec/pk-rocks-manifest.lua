--------------------------------------------------------------------------------
-- pk-rocks-manifest.lua: PK rocks manifest
-- This file is a part of Lua-Aplicado library
-- Copyright (c) Lua-Aplicado authors (see file `COPYRIGHT` for the license)
--------------------------------------------------------------------------------
local ROCKS =
{
  {
    "rockspec/lua-aplicado-scm-1.rockspec";
    generator =
    {
      "pk-lua-interpreter", "etc/rockspec/generate.lua", "scm-1",
        ">", "rockspec/lua-aplicado-scm-1.rockspec"
    };
  };
}

return
{
  ROCKS = ROCKS;
}
