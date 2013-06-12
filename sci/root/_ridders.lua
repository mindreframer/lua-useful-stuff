
local xsys = require "xsys"
local math = require "xsys.math"

local err, chk = xsys.handlers("xsys.root")
local max, abs, sqrt, sign = xsys.from(math, "max, abs, sqrt, sign")

local function ridders(f, xl, xu, stop)
  chk(xl < xu, "constraint", "xlower:",xl," not < xupper:",xu)
  local yl, yu = f(xl), f(xu)
  chk(yl*yu <= 0, "constraint", "root not bracketed by f(xlower):",yl,
      ", f(xupper):",yu)
  while true do
    local xm = xl + 0.5*(xu - xl) -- Avoid xm > xl or xm < xu.
    local ym = f(xm)
    local xe, ye
    do
      local d = ym^2 - yl*yu
      if d == 0 then -- Function is flat on xl, xm, xu.
        xe, ye = xm, ym
      else -- Exponential inversion.
        xe = xm + (xm - xl)*sign(yl - yu)*ym/sqrt(d)
        ye = f(xe)
      end
    end
    if stop(xe, ye, xl, xu) then
      return xe, ye, xl, xu
    end
    if ye*ym <= 0 then
      if xm < xe then
  xl, xu = xm, xe
  yl, yu = ym, ye
      else
  xl, xu = xe, xm
  yl, yu = ye, ym
      end
    elseif ym*yl <= 0 then
      xu, yu = xm, ym
    else
      xl, yl = xm, ym
    end
  end
end

return { ridders = ridders }