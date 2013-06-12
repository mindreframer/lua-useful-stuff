--------------------------------------------------------------------------------
-- Student-t statistical distribution.
--
-- Copyright (C) 2011-2012 Stefano Peluchetti. All rights reserved.
--
-- Features, documention and more: http://www.scilua.org .
--
-- This file is part of the SciLua library, which is released under the MIT 
-- license: full text in file LICENSE.TXT in the library's root folder.
--------------------------------------------------------------------------------

local xsys = require "xsys"
local ffi  = require "ffi"
local math = require "sci.math"

local M = {}

local err, chk = xsys.handlers("sci.dist")
local sqrt, log, pi, cos, gamma, loggamma, huge, beta, logbeta = xsys.from(math,
     "sqrt, log, pi, cos, gamma, loggamma, huge, beta, logbeta")

local stud_mt, stud_ct = {}
stud_mt.__index = stud_mt

function stud_mt:range()
  return -huge, huge
end

function stud_mt:pdf(x)
  local nu = self._nu
  return (1 + x^2/nu)^(-0.5*(nu + 1)) / (sqrt(nu)*beta(0.5, 0.5*nu))
end

function stud_mt:logpdf(x)
  local nu = self._nu
  return -(0.5*(nu + 1))*log(1 + x^2/nu) - 0.5*log(nu) - logbeta(0.5, 0.5*nu)
end

function stud_mt:mean()
	if self._nu <= 1 then 
    return 0/0
	else 
    return 0
	end
end

function stud_mt:variance()
  local nu = self._nu
	if nu <= 1 then 
    return 0/0
	elseif nu <= 2 then 
    return huge
	else 
    return nu/(nu - 2) 
	end
end

function stud_mt:absmoment(mm)
  local nu = self._nu
  local num = nu^(0.5*mm)*gamma(0.5*(mm+1))*gamma(0.5*(nu)) 
  local den = sqrt(pi)*gamma(0.5*nu)
  return num/den
end

function stud_mt:sample(rng)
  local nu, u1, u2 = self._nu, rng:sample(), rng:sample()
	return sqrt(nu*(u1^(-2/nu) - 1))*cos(2*pi*u2)
end

function stud_mt:copy()
  return stud_ct(self)
end

stud_ct = ffi.metatype("struct { double _nu; }", stud_mt)

function M.student(nu)
  nu = nu or 5 -- First integer with first 4 moments finite.
  chk(nu > 0, "constraint", "nu must be positive, nu=", nu)
  return stud_ct(nu)
end

return M