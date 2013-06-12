--------------------------------------------------------------------------------
-- Special math functions module.
--
-- Copyright (C) 2011-2012 Stefano Peluchetti. All rights reserved.
--
-- Features, documention and more: http://www.scilua.org .
--
-- This file is part of the SciLua library, which is released under the MIT 
-- license: full text in file LICENSE.TXT in the library's root folder.
--------------------------------------------------------------------------------

local ffi  = require "ffi"
local xsys = require "xsys"
local bit  = require "bit"

local M = {}
xsys.import(M, math)

local sqrt, exp, log, sin = math.sqrt, math.exp, math.log, math.sin
local abs, m_pi, m_e = math.abs, math.pi, math.exp(1)
local floor = math.floor

-- Utility functions -----------------------------------------------------------

-- Round number so that it has ndigits after the zero.
function M.round(num, ndigits)
  local tnum
  local rnum = num*10^ndigits
  if rnum < 0 then 
    tnum =  math.ceil(rnum < 0 and rnum - 0.5 or rnum + 0.5)
  else
    tnum = math.floor(rnum < 0 and rnum - 0.5 or rnum + 0.5)
  end
  return tnum/10^ndigits
end

function M.isnan(x)
  return x ~= x
end

-- All of the below returns false if it's nan as expected.
function M.isfinite(x)
  return abs(x) < math.huge
end

function M.isinteger(x)
  return x == floor(x)
end

function M.iseven(x)
  return x % 2 == 0
end

function M.isodd(x)
  return x % 2 == 1
end

-- Gamma function --------------------------------------------------------------

-- r(10).
local gamma_r10 = 10.900511

-- dk[0], ..., dk[10].
local gamma_dk = ffi.new("double[11]", 
  2.48574089138753565546e-5,
  1.05142378581721974210,
  -3.45687097222016235469,
  4.51227709466894823700,
  -2.98285225323576655721,
  1.05639711577126713077,
  -1.95428773191645869583e-1,
  1.70970543404441224307e-2,
  -5.71926117404305781283e-4,
  4.63399473359905636708e-6,
  -2.71994908488607703910e-9
)

local gamma_c = 2*sqrt(m_e/m_pi)

-- Lanczos approximation, see:
-- Pugh[2004]: AN ANALYSIS OF THE LANCZOS GAMMA APPROXIMATION
-- http://bh0.physics.ubc.ca/People/matt/Doc/ThesesOthers/Phd/pugh.pdf
-- pag 116 for optimal formula and coefficients. Theoretical accuracy of 
-- 16 digits is likely in practice to be around 14.
-- Domain: R except 0 and negative integers.
local function gamma(z)
  -- Reflection formula to handle negative z plane.
  -- Better to branch at z < 0 as some probabilistic use cases only consider the
  -- case z >= 0.
  if z < 0 then 
    return m_pi/(sin(m_pi*z)*gamma(1 - z)) 
  end  
  local sum = gamma_dk[0]
  -- for i=1,10 do 
    -- sum = sum + gamma_dk[i]/(z + i - 1) 
  -- end
  sum = sum + gamma_dk[1]/(z + 0)
  sum = sum + gamma_dk[2]/(z + 1) 
  sum = sum + gamma_dk[3]/(z + 2) 
  sum = sum + gamma_dk[4]/(z + 3) 
  sum = sum + gamma_dk[5]/(z + 4) 
  sum = sum + gamma_dk[6]/(z + 5) 
  sum = sum + gamma_dk[7]/(z + 6) 
  sum = sum + gamma_dk[8]/(z + 7) 
  sum = sum + gamma_dk[9]/(z + 8) 
  sum = sum + gamma_dk[10]/(z + 9)  
  return gamma_c*((z  + gamma_r10 - 0.5)/m_e)^(z - 0.5)*sum
end
M.gamma = gamma

-- Returns log(abs(gamma(z))).
-- Domain: R except 0 and negative integers.
local function logabsgamma(z)
  -- Reflection formula to handle negative real plane. Only sin can be negative.
  -- Better to branch at z < 0 as some probabilistic use cases only consider the
  -- case z >= 0.
  if z < 0 then 
    return log(m_pi) - log(abs(sin(m_pi*z))) - logabsgamma(1 - z) 
  end  
  local sum = gamma_dk[0]
  -- for i=1,10 do 
    -- sum = sum + gamma_dk[i]/(z + i - 1) 
  -- end
  sum = sum + gamma_dk[1]/(z + 0)
  sum = sum + gamma_dk[2]/(z + 1) 
  sum = sum + gamma_dk[3]/(z + 2) 
  sum = sum + gamma_dk[4]/(z + 3) 
  sum = sum + gamma_dk[5]/(z + 4) 
  sum = sum + gamma_dk[6]/(z + 5) 
  sum = sum + gamma_dk[7]/(z + 6) 
  sum = sum + gamma_dk[8]/(z + 7) 
  sum = sum + gamma_dk[9]/(z + 8) 
  sum = sum + gamma_dk[10]/(z + 9) 
  -- For z >= 0 gamma function is positive, no abs() required.
  return log(gamma_c) + (z - 0.5)*log(z  + gamma_r10 - 0.5) 
    - (z - 0.5) + log(sum)
end
M.logabsgamma = logabsgamma

-- Beta function ---------------------------------------------------------------

-- Domain: a > 0 and b > 0.
local function logbeta(a, b)
  if a <= 0 or b <= 0 then return 0/0 end
  return logabsgamma(a) + logabsgamma(b) - logabsgamma(a + b)
end
M.logbeta = logbeta

-- Domain: a > 0 and b > 0.
local function beta(a, b)
  return exp(logbeta(a, b))
end
M.beta = beta

return M