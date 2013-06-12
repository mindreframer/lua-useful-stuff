--------------------------------------------------------------------------------
-- pk-engine.lua: pk-engine exports profile
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
    "schema/client_api/client_api_version.lua";
    "schema/client_api/geoip_city/ext.lua"
}, {
  __index = function(t, k)
    -- Excluding files outside of pk-engine/ and inside pk-engine/code
    -- and inside pk-engine/test

    local v = k:match("^schema/verbatim/code/")
      or (k:sub(1, #"schema/test/") == "schema/test/")

    t[k] = v
    return v
  end;
})

--------------------------------------------------------------------------------

return PROFILE
