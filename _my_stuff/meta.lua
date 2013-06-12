#!/usr/bin/env lua

-- __add
-- __sub
-- __mul
-- __div
-- __pow
-- __lt
-- __le
-- __eq
-- __call
-- __unm
-- __tostring
-- __len



t, mt = {a = 1}, {}
print(getmetatable(t))       --> nil
setmetatable(t, mt)
print(getmetatable(t) == mt) --> true

print(getmetatable("hi"))

complex = {}
function complex.new(re, im)
  return setmetatable({re,im}, complex)
end

function complex.__add(x,y)
  return complex.new(x[1] + y[1], x[2] + y[2])
end

function complex.__sub(x,y)
  return complex.new(x[1] - y[1], x[2] - y[2])
end

function complex.__mul(x,y)
  local a,b, c,d = x[1],x[2], y[1],y[2]
  return complex.new(a*c - b*d, a*d + b*c)
end

function complex.__div(x,y)
  local a,b, c,d = x[1],x[2], y[1],y[2]
  local re = (a*c + b*d)/(c*c + d*d)
  local im = (b*c - a*d)/(c*c + d*d)
  return complex.new(re, im)
end

function complex.__eq(x,y)
  return x[1] == y[1] and x[2] == y[2]
end

function complex.__le(a,b)
  return x[1] < y[1] and x[2] <= y[2]
end

function complex.__lt(a,b)
  local a,b,c,d = x[1],x[2], y[1],y[2]
  return a < c or (a == c and b <= d)
end

function complex.__tostring(a)
  return "(" .. a[1] .. " + " .. a[2] .. "i)"
end

function complex.__concat(a,b)
  return tostring(a) .. tostring(b)
end

function complex.__index(x, k)
  return ({re = x[1], im = x[2]})[k]
end

function complex.__newindex(x, k, v)
  local i = ({re = 1, im = 2})[k]
  x[i] = v
end

a,b = complex.new(1,2), complex.new(3,4)
c,d,e =  a+b, a*b, a/b
print(c)

print(complex.new(2,3)) --> (2 + 3i)
s = "answer = " .. complex.new(4,2)
print(s)                --> answer = (4 + 2i)

c = complex.new(math.pi, -1)
print(c.re, c.im) --> 3.14159...   -1

c.re, c.im = 3, 1
print(c.re, c.im) --> 3    1


-- images = setmetatable({}, {__index = function(_, p)
--   p = "images/" .. p .. ".png"
--   print("loading", p)
--   local img    = "aa"
--   images[path] = img
--   return img
-- end})

-- print(images.troll) --> loading   images/troll.png
-- print(images.troll) --> <nix>




function readOnly(t)
  return setmetatable(t, {__newindex = function(_,k)
    error("Cannot create field " .. k)
  end})
end

t = readOnly{
  foo = 1,
  bar = 2
}
t.foo = 4
-- t.baz = 3 --> stdin:1: Cannot create field baz

