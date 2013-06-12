--------------------------------------------------------------------------------
-- pk-engine.lua: pk-engine exports profile
-- This file is a part of pk-engine library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------

local tset = import 'lua-nucleo/table-utils.lua' { 'tset' }

--------------------------------------------------------------------------------

local PROFILE = { }

--------------------------------------------------------------------------------

declare 'copcall' -- TODO: Uberhack! :(
require 'copas' -- TODO: Uberhack! :(
declare 'wsapi' -- TODO: Uberhack! :(

PROFILE.skip = setmetatable(tset
{
  "pk-engine/webservice/init/init.lua"; -- Too low-level
  "pk-engine/webservice/init/require.lua"; -- Too low-level
  "pk-engine/fake_uuids.lua"; -- Contains linear data array
  "pk-engine/srv/channel/main.lua"; -- Too low-level
  "pk-engine/module.lua"; -- Too low-level
   -- Exports rarely used symbols, obscuring some commonly used module names.
   "pk-engine/webservice/client_api/check.lua";
}, {
  __index = function(t, k)
    -- Excluding files outside of pk-engine/ and inside pk-engine/code
    -- and inside pk-engine/test

    local v = (not k:match("^pk%-engine/"))
      or k:match("^pk%-engine/code/")
      or (k:sub(1, #"pk-engine/test/") == "pk-engine/test/")

    t[k] = v
    return v
  end;
})

--------------------------------------------------------------------------------

return PROFILE
