--------------------------------------------------------------------------------
-- Statistical functionalities module.
--
-- Copyright (C) 2011-2012 Stefano Peluchetti. All rights reserved.
--
-- Features, documention and more: http://www.scilua.org .
--
-- This file is part of the SciLua library, which is released under the MIT 
-- license: full text in file LICENSE.TXT in the library's root folder.
--------------------------------------------------------------------------------

local xsys = require "xsys"
local alg  = require "sci.alg" 

local M = {}

local err, chk = xsys.handlers("sci.stat")
local vec = alg.vec
local eqsize = alg.check.eqsize

-- Metamethods for parametric model --------------------------------------------

local function param_fixed(t)
  local xl, xu = vec(t.lower), vec(t.upper)
  local np     = #xl
  local valid  = t.valid
  local set	   = t.set
  eqsize(xl, xu, "bounds") 
  local o = {
    dimparam   = function()
      return np
    end,
    rangeparam = function()
      return xl:copy(), xu:copy()
    end,
    validparam = valid,
    setparam   = function(self, ...)
      if not valid(self, ...) then
  local p = ...
  err("constraint", "trying to set vector of not valid parameters, values:"
      ..tostring(p))
      end
      set(self, ...)
    end,
  }
  return o
end

local function dimparams1(self)
  return self._dimparam
end

local function rangeparams1(self)
  return self._lowerparam:copy(), self._upperparam:copy()
end

local function param_self(t)
  local valid = t.valid
  local set	  = t.set
  local o = {
    dimparam   = dimparams1,
    rangeparam = rangeparams1,
    validparam = valid,
    setparam   = function(self, ...)
      if not valid(self, ...) then
  local p = ...
  err("constraint", "trying to set vector of not valid parameters, values:"
      ..tostring(p))
      end
      set(self, ...)
    end,
  }
  return o
end

local function dimparams0()
  return 0
end

local function rangeparams0(self)
  return nil, nil
end

local function validparams0(self, p)
  return type(p) == "nil"
end

local function setparams0(self, p)
  chk(type(p) == "nil", "no parameters required")
end

local function param_no()
  local o = {
    dimparam   = dimparams0,
    rangeparam = rangeparams0,
    validparam = validparams0,
    setparam   = setparams0,
  }
  return o
end

function M.mtparam(t)
  if t then
    if t.lower then
      return param_fixed(t)
    else
      return param_self(t)
    end
  else
    return param_no()
  end
end

-- Log-likelyhood functions ----------------------------------------------------
function M.loglikel(model, data)
  model, data = xsys.copy(model, data)
  return function(p)
    if not model:validparam(p) then
      return -math.huge
    else
      model:setparam(p)
      return model:logpdf(data)
    end
  end
end

-- BIC: -2*loglikel(mle) + K*log(N)
function M.bic(maxloglikel, dimparam, samples)
  return -2*maxloglikel + dimparam*math.log(samples)
end

-- Core statistics -------------------------------------------------------------



return M