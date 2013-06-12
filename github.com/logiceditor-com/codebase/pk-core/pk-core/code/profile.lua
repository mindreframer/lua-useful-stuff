--------------------------------------------------------------------------------
-- pk-core.lua: pk-core exports profile
-- This file is a part of pk-core library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------

local tset = import 'lua-nucleo/table-utils.lua' { 'tset' }

--------------------------------------------------------------------------------

local PROFILE = { }

--------------------------------------------------------------------------------

PROFILE.skip = setmetatable(tset
{
  "pk-core/module.lua"; -- Too low-level
}, {
  __index = function(t, k)
    -- Excluding files outside of pk-core/ and inside pk-core/code
    local v = (not k:match("^pk%-core/")) or k:match("^pk%-core/code/")
    t[k] = v
    return v
  end;
})

--------------------------------------------------------------------------------

return PROFILE
