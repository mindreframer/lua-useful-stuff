--------------------------------------------------------------------------------
-- profile.lua: exports profile
-- This file is a part of pk-admin library
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
  -- Nothing to skip
}, {
  __index = function(t, k)
    -- Excluding files outside of pk-admin/ and inside pk-admin/code
    local v = (not k:match("^pk%-admin/")) or k:match("^pk%-admin/code/")
    t[k] = v
    return v
  end;
})

--------------------------------------------------------------------------------

return PROFILE
