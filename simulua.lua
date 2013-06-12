-- Simulua: discrete-event simulation, based on Simula
-- Version: 0.1
-- Check license at the bottom of the file
-- $Id: simulua.lua,v 1.1 2008-08-19 23:36:38 carvalho Exp $

local setmetatable, getmetatable = setmetatable, getmetatable
local assert, error, type = assert, error, type
local yield, create, resume = coroutine.yield, coroutine.create, coroutine.resume
local heap = require "binomial"

module "simulua"

-- internals
local procmt = {} procmt.__metatable = procmt -- protected metatable
local thread = setmetatable({}, {__mode = "k"}) -- thread cache
local events -- event list
local isidle -- idle event set
-- simulation globals
local _time, _current -- current time and process
local main -- main thread

local function cancelprocess (proc)
  if events:remove(proc) then -- removed?
    isidle[proc] = true -- add to idle event set
  end
end

local function checkprocess (proc)
  assert(getmetatable(proc) == procmt,
      "process expected, got " .. type(proc))
  return proc
end

local function scheduler () -- generator
  return create(function()
    while true do
      if events:isempty() then break end
      _time, _current = events:min()
      local active, op, p, d, after = resume(thread[_current])
      if not active then yield(op) end -- propagate error
      if op ~= nil then
        if op == "hold" then
          if type(p) ~= "number" or p < 0 then p = 0 end
          events:change(_current, _time + p) -- with priority
        elseif op == "cancel" then
          cancelprocess(checkprocess(p))
        elseif op == "activate" then
          -- set delay time
          local delay
          if d == nil then delay = 0
          elseif type(d) == "number" then
            delay = d >= 0 and d or 0
          else -- process
            d = checkprocess(d)
            if not isidle[d] then
              d = events:get(d) -- d's time
              if d ~= nil then -- in event list?
                delay = d - _time -- relative delay
              end
            end
          end
          p = checkprocess(p)
          if delay == nil then
            cancelprocess(p)
          else
            if isidle[p] or events:get(p) == nil then
              events:insert(_time + delay, p, after)
              isidle[p] = nil -- remove from idle set
            else -- reactivate
              events:change(p, _time + delay, after)
            end
          end
        else -- failsafe
          yield("unknown operation: " .. op)
        end
      else
        if _current == main then break end -- stop simulation
        cancelprocess(_current) -- passivate
      end
    end
  end)
end


-- =======   simulation   =======
function process (task, att)
  local p = setmetatable(att or {}, procmt)
  thread[p] = create(task)
  return p
end

-- query
function current () return _current end

function time (proc)
  if proc == nil then return _time end
  return events:get(checkprocess(proc))
end

function idle (proc)
  local p = checkprocess(proc)
  return isidle[p] or events:get(p) == nil -- idle or not scheduled yet?
end

-- actions
function hold (delay) yield("hold", delay) end
function cancel (proc) yield("cancel", proc) end
function passivate () yield("cancel", _current) end

function activate (proc, d, after)
  yield("activate", proc, d, after)
end

function wait (res, ...)
  assert(res ~= nil, "invalid resource")
  assert(type(res.into) == "function",
      "resource has invalid `into' method")
  res:into(_current, ...)
  yield("cancel", _current) -- passivate
end

-- simulation control
function start (task)
  events, isidle, main = heap(), {}, process(task)
  events:insert(0, main)
  local active, msg = resume(scheduler())
  assert(active, msg)
  if msg ~= nil then error(msg) end
end

function stop () yield("cancel", main) end

-- =======   accumulator   =======
local _acc = {
  __index = { -- methods
    update = function(a, v, t)
      local time = t or _time
      assert(v ~= nil and type(v) == "number", "invalid value to update")
      assert(type(time) == "number", "invalid time to update")
      local last = a.last
      a.mean = (a.mean * last + (time - last) * v) / time
      a.last = time
    end
  }
}
_acc.__metatable = _acc -- protect

function accumulator ()
  return setmetatable({last = 0, mean = 0}, _acc)
end

--[[
Copyright (c) 2008 Luis Carvalho

Permission is hereby granted, free of charge, to any person
obtaining a copy of this software and associated documentation files
(the "Software"), to deal in the Software without restriction,
including without limitation the rights to use, copy, modify,
merge, publish, distribute, sublicense, and/or sell copies of the
Software, and to permit persons to whom the Software is furnished
to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
--]]
