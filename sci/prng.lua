--------------------------------------------------------------------------------
-- Pseudo random number generators module.
--
-- Copyright (C) 2011-2012 Stefano Peluchetti. All rights reserved.
--
-- Features, documention and more: http://www.scilua.org .
--
-- This file is part of the SciLua library, which is released under the MIT 
-- license: full text in file LICENSE.TXT in the library's root folder.
--------------------------------------------------------------------------------

local xsys = require "xsys"

local M = {}

xsys.table.eval({
  "marsaglia", 
  "mrg",
}, function(x) xsys.import(M, require("sci.prng._"..x)) end)

-- Define standard random number generator.
M.std = M.lfib4

return M