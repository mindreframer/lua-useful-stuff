#!/usr/bin/env lua

-- http://www.wellho.net/resources/U107.html
-- https://github.com/Olivine-Labs/luassert
-- luarocks install luassert

-- luarocks install telescope

-- https://github.com/kikito/inspect.lua
-- luarocks install inspect

local inspect = require 'inspect'
local assert = require("luassert")

-- custom matchers
require 'spec_helper'
assert.has_property("name", { name = "jack" })
assert.matches("hello", "hello, my friend")


-- prettyprint
function pp(v)
  print (v)
  print(inspect(v))
end

-- a generic add function for arrays
function add (a)
  local sum = 0
  for i,v in ipairs(a) do
    sum = sum + v
  end
  return sum
end

print(add({1,3,3,6,4544545}))

-- work with tables
function maximum (a)
  local mi = 1 -- index of the maximum value
  local m = a[mi] -- maximum value
  for i,val in ipairs(a) do
    if val > m then
      mi = i; m = val
    end
  end
  return m, mi
end

print(maximum({8,10,23,12,5}))

-- A special function with multiple returns is unpack.
-- It receives an array and returns as results all elements from the array, starting from index 1:
print(unpack{10,20,30})
a,b = unpack{10,20,30} -- a=10, b=20, 30 is discarded

print("----- Some unpacking magic ------- ")
f = string.find
a = {"hello", "ll"}
print(f(unpack(a)))

--- variable arguments for functions with 3 dots : ...
-- The three dots (...) in the parameter list indicate that the function accepts a variable number of arguments

-- add with unlimited args
function add (...)
  local s = 0
  for i, v in ipairs{...} do
    s=s+v
  end
  return s
end
print(add(3, 4, 10, 25, 12)) --> 54

-- write to IO
function fwrite (fmt, ...)
  return io.write(string.format(fmt, ...))
end

fwrite("a")
fwrite("%d%d", 4, 5)
print("")

--- 5.3 named arguments

function rename (arg)
  return os.rename(arg.old, arg.new)
end

-- it won't blow up, if the file is not present!
-- check the return value ->
r = rename{old="temp.txt", new="temp1.txt"}
assert(r, "file for renaming not found!")
-- rename back
rename{old="temp1.txt", new="temp.txt"}

-- example call

--[[
w = Window{ x=0, y=0, width=300, height=200,
  title = "Lua", background="blue",
  border = true
}

-- The Window function then has the freedom to check for mandatory arguments, add default values, and the like.
]]--

function Window (options)
  pp(options)
  -- check mandatory options
  if type(options.title) ~= "string" then
    error("no title")
  elseif type(options.width) ~= "number" then
    error("no width")
  elseif type(options.height) ~= "number" then
    error("no height")
  end
  -- everything else is optional
  _Window(options.title,
    options.x or 0, -- default value
    options.y or 0, -- default value
    options.width, options.height,
    options.background or "white", -- default
    options.border -- default is false (nil)
  )
end

function _Window(title, x,y,width, height, background, border)
  print "creating window object with:"
  pp(title,x,y,width, height, background, border)
end

w = Window{ x=0, y=0, width=300, height=200,
  title = "Lua", background="blue",
  border = true
}

--- Chapter 6 - Functions

network = {
  {name = "grauna", IP = "210.26.30.34"},
  {name = "arraial", IP = "210.26.30.23"},
  {name = "lua", IP = "210.26.23.12"},
  {name = "derain", IP = "210.26.23.20"},
}

print("\nsort by name ascending")
table.sort(network, function (a,b) return (a.name < b.name) end)
pp(network)
assert(network[1].name == "arraial")

print("\nsort by IP ascending")
table.sort(network, function (a,b) return (a.IP < b.IP) end)
pp(network)
assert(network[1].IP == "210.26.23.12")

-- 6.1 Closures

function newCounter ()
  local i = 0
  -- anonymous function
  return function ()
    i=i+1
    return i
  end
end

c1 = newCounter()
assert(c1() == 1) --> 1
assert(c1() == 2) --> 2

c2 = newCounter()
assert(c2() == 1) --> 1
assert(c2() == 2) --> 1

-- monkey patching?
-- with global oldSin
oldSin = math.sin
math.sin = function (x)
  return oldSin(x*math.pi/180)
end

-- a cleaner way

do
  local oldSin = math.sin
  local k = math.pi/180
  math.sin = function (x)
    print("CUSTOM SIN FUNCTION")
    return oldSin(x*k)
  end
end

print(math.sin(300))

-- secure environments, sandboxes
-- that is a great technique!
--[[
do
  local oldOpen = io.open
  local access_OK = function (filename, mode)
    -- check access>
  end
  io.open = function (filename, mode)
    if access_OK(filename, mode) then
      return oldOpen(filename, mode)
    else
      return nil, "access denied"
    end
  end
end
]]

-- 6.2 Non-Global Functions

Lib = {}
Lib.foo = function (x,y) return x + y end
Lib.goo = function (x,y) return x - y end

assert(Lib.foo(1,3) == 4)

-- So, we can use this syntax for recursive functions without worrying:
local function fact (n)
  if n == 0 then return 1
  else return n*fact(n-1)
  end
end

assert(fact(1) == 1)
assert(fact(2) == 2)
assert(fact(3) == 6)

-- 6.3 Proper Tail Calls

-- For instance, we can call the following function passing any number as argument;
-- it will never overflow the stack:
function foo (n)
  if n > 0 then return foo(n - 1) end
end

-- In Lua, only a call with the form returnfunc(args) is a tail call
-- However, both func and its arguments can be complex expressions,
-- because Lua evaluates them before the call. For instance, the next call is a tail call:
--> return x[i].foo(x[j] + a*b, i + j)

function room1 ()
  print("in room1")
  local move = io.read()
  if move == "south" then return room3()
  elseif move == "east" then return room2()
  else
    print("invalid move")
    return room1() -- stay in the same room
  end
end
function room2 ()
  print("in room2")
  local move = io.read()
  if move == "south" then return room4()
  elseif move == "west" then return room1()
  else
    print("invalid move")
    return room2()
  end
end
function room3 ()
  print("in room3")
  local move = io.read()
  if move == "north" then return room1()
  elseif move == "east" then return room4()
  else
    print("invalid move")
    return room3()
  end
end
function room4 ()
  print("in room4")
  print("congratulations!")
end

--- uncomment to play the rooms game :)
-- room1()



-- 7 - Iterators and the Generic `for`
-- Listing 7.1. Iterator to traverse all words from the input file:
function allwords ()
  local line = io.read()  -- current line
  local pos = 1
  return function ()
    -- current position in the line
    -- iterator function
    -- repeat while there are lines
    while line do
      local s, e = string.find(line, "%w+", pos)
      if s then           -- found a word?
        pos = e + 1       -- next position is after this word
        return string.sub(line, s, e)     -- return the word
      else
        line = io.read()  -- word not found; try next line
        pos = 1 -- restart from first position
      end
    end
    return nil -- no more lines: end of traversal
  end
end


-- 7.3 Stateless Iterators



--- 8 - Compilation, Execution,8and Errors

-- we introduced dofile as a kind of primitive operation to run chunks of Lua code,
-- loadfile loads a Lua chunk from a file, but it does not run the chunk.
-- Instead, it only compiles the chunk and returns the compiled chunk as a function.
-- Moreover, unlike dofile, loadfile does not raise errors,
-- but instead returns error codes, so that we can handle the error.

-- For simple tasks, dofile is handy, because it does the complete job in one
-- call. However, loadfile is more flexible.
-- In case of error, loadfile returns nil plus the error message,
-- which allows us to handle the error in customized ways.

-- The loadstring function is similar to loadfile, except that
-- it reads its chunk from a string, not from a file.

f = loadstring("i = i + 1")
i=0
f();
assert(i == 1) -- 1
f()
assert(i == 2) -- 2

-- reverse a string
assert(string.gsub("hello Lua", "(.)(.)", "%2%1") == "ehll ouLa") -- ??? a strange beast..



-- scoping for loadstring

i = 32
local i = 0

-- f manipulates a global i,
-- because loadstring always compiles its strings in the global environment.
f = loadstring("i = i + 1; return (i)")
-- The g function manipulates the local i
g = function () i = i + 1; return (i) end
assert(f() == 33)
assert(g() == 1)


-- this will evaluate a function and print results from 1 to 20
function plotgraph()
  print "enter function to be plotted (with variable ’x’):"
  local l = io.read()
  local f = assert(loadstring("return " .. l))
  for i=1,20 do
    x = i   -- global ’x’ (to be visible from the chunk)
    print(string.rep("*", f()))
  end
end

-- try with: x * 2, (10-x)* x
-- plotgraph()

--[[
If we go deeper, we find out that the real primitive in Lua is
neither loadfile nor loadstring, but load.
Instead of reading a chunk from a file, like loadfile, or from a string, like loadstring,
load receives a reader function that it calls to get its chunk

Lua treats any independent chunk as the body of an anonymous function
with a variable number of arguments.

loadstring("a = 1") re- turns the equivalent of the following expression:
     function (...) a = 1 end


The load functions never raise errors. In case of any kind of error,
they return nil plus an error message:

]]--


res, err = loadstring("i i")
assert.are.equal(err, "[string \"i i\"]:1: '=' expected near 'i'")

-- If it complains about a non-existent file,
-- then you have dynamic linking facility.
res, err = package.loadlib("a","b")
assert.are.equal(err, 'dlopen(a, 2): image not found')

-- Lua provides all the functionality of dynamic linking
-- in a single function, called package.loadlib

---- So, a typical call to it looks like the next fragment:
-- local path = "/usr/local/lib/lua/5.1/socket.so"
-- local f = package.loadlib(path, "luaopen_socket")

-- Instead, it returns the C function as a Lua function.
-- Usually, we load C libraries using require


-- 8.3 Errors ---


-- local file, msg
-- repeat
--   print "enter a file name:"
--   --local name = io.read()
--   local name = "temp.txt"
--   if not name then return end
--   file, msg = io.open(name, "r")
--   if not file then print(msg) end
-- until file

--- read file
-- filename = "temp.txt"
-- file, msg = io.open(filename, "r")
-- print(msg)


f, err=io.open("textfile.txt","w")
if(not err) then
  f:write("testing stuff")
end
f:close()

-- custom reading function
function readfile(filename)
  local f, err = io.open(filename, "rb")
  if(not err) then
    local content = f:read("*all")
    f:close()
    return content
  end
end

assert.are.equal(readfile("textfile.txt"), "testing stuff")


-- 8.4 Error Handling and Exceptions
-- If you need to handle errors in Lua,
-- you must use the pcall function (pro- tected call) to encapsulate your code.


local status, err = pcall(function () error({code=121}) end)
assert(err.code == 121)

-- These mechanisms provide all we need to do exception handling in Lua.
-- We throw an exception with error and catch it with pcall.
-- The error message identifies the kind or error.


-- 8.5 Error Messages and Tracebacks

local status, err = pcall(function () a = "a"+1 end)
assert.matches("attempt to perform arithmetic on a string value", err)



function foo(str)
   if type(str) ~= "string" then
     error("string expected")
   end
   print("FOO" .. str)
end


-- the backtrace level
function fooWithRightLevel(str)
   if type(str) ~= "string" then
     error("string expected", 2)
   end
   print("FOO" .. str)
end

local status, err = pcall(function() foo({x=1}) end)
assert.matches("lua:468", err) -- location in foo function

local status, err = pcall(function() fooWithRightLevel({x=1}) end)
assert.matches("lua:485", err) -- location is the above line
assert.matches("./basics.lua:487: in main chunk", debug.traceback())


-- 9 - Coroutines
--[[
Coroutines, on the other hand, are collaborative:
at any given time, a program with coroutines is running
only one of its coroutines, and this running coroutines
suspends its execution only when it explicitly requests to be suspended.
]]

co = coroutine.create(function () print("hi") end)
assert.matches("thread", tostring(co)) -- thread/coroutine

-- We can check the state of a coroutine with the status function:
assert.equal(coroutine.status(co), "suspended")


--  function coroutine.resume (re)starts the execution of a coroutine
coroutine.resume(co) --> hi

-- coroutine in the dead state, from which it does not return:
assert.equal(coroutine.status(co), "dead")


-- The real power of coroutines stems from the yield function,
-- which allows a running coroutine to suspend its own execution
-- so that it can be resumed later.

co = coroutine.create(function ()
  for i=1,10 do
    print("co", i)
    coroutine.yield()
  end
end)

coroutine.resume(co)

--- 11 Data Structures

-- 11.1 Arrays
 a = {}    -- new array
for i=1, 1000 do
  a[i] = 0
end

assert.equal(#a, 1000)

-- 11.2 Matrices and Multi-Dimensional Arrays

local N,M = 10, 20
mt = {} -- create the matrix
for i=1,N do
  mt[i] = {} -- create a new row
  for j=1,M do
    mt[i][j] = 0
  end
end


-- 11.3 Linked Lists
list = nil
list = {next = list, value = v}
--  However, you seldom need those structures in Lua,
-- because usually there is a simpler way to represent your
-- data without using linked lists.


pp(package.path)
pp(package.searchers)
pp(package.searchpath)


-- 13 - Metatables and Metamethods


-- 13.1 Arithmetic Metamethods
Set = {}
local mt = {}    -- metatable for sets
-- create a new set with the values of the given list
function Set.new (l)
  local set = {}
  setmetatable(set, mt)
  for _, v in ipairs(l) do set[v] = true end
  return set
end
function Set.union (a, b)
  local res = Set.new{}
  for k in pairs(a) do res[k] = true end
  for k in pairs(b) do res[k] = true end
  return res
end
function Set.intersection (a, b)
  local res = Set.new{}
  for k in pairs(a) do
   res[k] = b[k]
  end
  return res
end

function Set.tostring (set)
  local l = {}     -- list to put all elements from the set
  for e in pairs(set) do
   l[#l + 1] = e
  end
  return "{" .. table.concat(l, ", ") .. "}"
end

function Set.print (s)
  print(Set.tostring(s))
end


s1 = Set.new{10, 20, 30, 50}
s2 = Set.new{30, 1}
assert.equal( getmetatable(s1), getmetatable(s2) )
-- Finally, we add to the metatable the metamethod,
-- a field __add that describes how to perform the addition:
mt.__add = Set.union
mt.
s3 = s1 + s2
print(s3)
-- assert.equal(tostring(s3), "")