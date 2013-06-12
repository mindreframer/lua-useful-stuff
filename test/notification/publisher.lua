local config = require'zbus.json'
local publisher = require'zbus.member'.new(config)
local ev = require'ev'

local counter = 0

local ticker = ev.Timer.new(
   function()
      -- send two notifications in one 'physical' message by using the more param
      print('TICK')
      publisher:notify_more('counter_simple',true,counter,counter+1)
      publisher:notify_more('counter_object',false,{counter=counter,next=counter+1})
      counter = counter + 1
   end,0.01,0.01)

ticker:start(ev.Loop.default)

ev.Loop.default:loop()
