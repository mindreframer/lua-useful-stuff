--------------------------------------------------------------------------------
-- Numerical integration (quadrature) module.
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
  "dblexp", 
}, function(x) xsys.import(M, require("sci.quad._"..x)) end)

return M