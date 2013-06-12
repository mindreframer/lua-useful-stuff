--------------------------------------------------------------------------------
-- Expressions module.
--
-- Copyright (C) 2011-2012 Stefano Peluchetti. All rights reserved.
--
-- Features, documention and more: http://www.scilua.org .
--
-- This file is part of the SciLua library, which is released under the MIT 
-- license: full text in file LICENSE.TXT in the library's root folder.
--------------------------------------------------------------------------------

local M = {}

local boolexpr_mt; boolexpr_mt = {
__call = function(self, ...)
  return self._(...)
end,
__mul = function(self, rhs) -- Corresponds to AND.
  local o = { _ = function(...) return self(...) and rhs(...) end }
  return setmetatable(o, boolexpr_mt)
end,
__add = function(self, rhs) -- Corresponds to OR.
  local o = { _ = function(...) return self(...) or rhs(...) end }
  return setmetatable(o, boolexpr_mt)
end,
}

function boolexpr(f)
  return setmetatable({ _ = f }, boolexpr_mt)
end

local boolgen_mt; boolgen_mt = {
__call = function(self)
  return self._()
end,
__mul = function(self, rhs) -- Corresponds to AND.
  local o = { _ = function() return boolexpr(self()) * boolexpr(rhs()) end }
  return setmetatable(o, boolgen_mt)
end,
__add = function(self, rhs) -- Corresponds to OR.
  local o = { _ = function() return boolexpr(self()) + boolexpr(rhs()) end }
  return setmetatable(o, boolgen_mt)
end,
}

function M.boolgen(g)
  return setmetatable({ _ = g }, boolgen_mt)
end

return M
