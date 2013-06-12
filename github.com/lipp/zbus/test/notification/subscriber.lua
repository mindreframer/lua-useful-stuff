local config = require'zbus.json'
local subscriber = require'zbus.member'.new(config)

local c1_finished
local c2_finished

local c1_start
local c1

subscriber:listen_add(
   '^counter_simple$',
   function(topic,more,counter,next)
      assert(topic == 'counter_simple')
      assert(next-1 == counter)
      if not c1_start then
         c1_start = counter
         c1 = counter
      else
         assert(c1+1 == counter)
         c1 = counter
      end            
      if c1-c1_start == 100 then
         subscriber:listen_remove('^counter_simple$')
         c1_finished = true
         if c1_finished and c2_finished then
            subscriber:unloop()
         end
      end
   end)

local c2_start
local c2

subscriber:listen_add(
   '^counter_object$',
   function(topic,more,content)
      assert(topic == 'counter_object')
      assert(content.next-1 == content.counter)
      if not c2_start then
         c2_start = content.counter
         c2 = content.counter
      else
         assert(c2+1 == content.counter)
         c2 = content.counter
      end            
      if c2-c2_start == 100 then
         subscriber:listen_remove('^counter_object$')         
         c2_finished = true
         if c1_finished and c2_finished then
            subscriber:unloop()
         end
      end
   end)

subscriber:loop()
os.exit(0)
