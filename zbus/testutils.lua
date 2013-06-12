local os = os
local io = io
local assert = assert
local type = type
local pairs = pairs
local print = print
local socket = require'socket'
local tonumber = tonumber
module('testutils')

deepcompare = 
   function(t1,t2)
      local ty1 = type(t1)
      local ty2 = type(t2)
      if ty1 ~= ty2 then return false end
      if ty1 ~= 'table' and ty2 ~= 'table' then 
         return t1 == t2 
      end
      for k1,v1 in pairs(t1) do
         local v2 = t2[k1]
         if v2 == nil or not deepcompare(v1,v2) then 
            return false 
         end
      end
      for k2,v2 in pairs(t2) do
         local v1 = t1[k2]
         if v1 == nil or not deepcompare(v1,v2) then 
            return false 
         end
      end
      return true
   end

sleep = socket.sleep

process = 
   function(cmd)
      local cmd_file = cmd:gsub('[^%w]','_')
      local ext_cmd = [[
            %s 1>/tmp/%s.stdout 2>/tmp/%s.stdout &
            XPID=`echo $!`
            echo $XPID
            wait $XPID 1>/dev/null 2>/dev/null
            echo $?            
      ]]
      ext_cmd = ext_cmd:format(cmd,cmd_file,cmd_file,cmd_file)
      local process = io.popen(ext_cmd)
      local pid = process:read()
      return {
         name = cmd,
         pid = pid,
         wait = 
            function()
               local exit_code = process:read()
               return tonumber(exit_code)
            end,
         kill = 
            function()
               os.execute('kill '..pid..' 1>/dev/null 2>/dev/null')               
            end
      }
   end

return {
   deepcompare = deepcompare,
   process = process,
   sleep = sleep
}

