local ev = require'ev'
local socket = require'socket'
require'pack'

local print = print
local pairs = pairs
local tinsert = table.insert
local tconcat = table.concat
local ipairs = ipairs
local assert = assert
local spack = string.pack
local error = error
local log = print

module('zbus.socket')

local wrap_sync = 
   function(sock)
      if not sock then
         error('can not wrap nil socket')
      end
      return {
         receive_message = 
            function(_)
               local parts = {}
               while true do
                  local header,err = sock:receive(4)
                  if err then
                     error('could not read header:'..err)
                  end
                  local _,bytes = header:unpack('>I')
                  if bytes == 0 then 
                     break
                  end
                  local part = sock:receive(bytes)
                  assert(part)
                  tinsert(parts,part)
               end
               --      print('RECV',#parts,tconcat(parts))
               return parts
               end,
         send_message = 
            function(_,parts)
               local message = ''
               for i,part in ipairs(parts) do
                  local len = #part
                  assert(len>0)
                  message = message..spack('>I',len)..part
               end
               message = message..spack('>I',0)      
               sock:send(message)
            end,
         getfd = 
            function()
               return sock:getfd()
            end,
         close = 
            function()
               sock:shutdown()
               sock:close()
            end
      }
   end

local wrap_async = 
   function(sock)
      if not sock then
         error('can not wrap nil socket')
      end
      sock:settimeout(0)
      sock:setoption('tcp-nodelay',true)
      local on_message = function() end
      local on_close = function() end
      local wrapped = {}
      wrapped.send_message =                              
         function(_,parts)
--            assert(#parts>0)
--            print('SND',#parts,tconcat(parts))
            local message = ''
            for i,part in ipairs(parts) do
               message = message..spack('>I',#part)..part
            end
            message = message..spack('>I',0)
            local len = #message
            assert(len>0)
            local pos = 1
            local fd = sock:getfd()
            assert(fd > -1)
            ev.IO.new(
               function(loop,write_io)                                
                  while pos < len do
                     local err                                    
                     pos,err = sock:send(message,pos)
                     if not pos then
                        if err == 'timeout' then
                           return
                        elseif err == 'closed' then
                           write_io:stop(loop)
                           sock:shutdown()
                           sock:close()
                           return
                        end
                     end
                  end
                  write_io:stop(loop)
               end,
               fd,
               ev.WRITE
            ):start(ev.Loop.default)
         end
      wrapped.on_close = 
         function(_,f)
            on_close = f
         end
      wrapped.on_message = 
         function(_,f)
            on_message = f
         end     
      wrapped.close =
         function()
            sock:shutdown()
            sock:close()
--            sock = nil
         end
      wrapped.read_io = 
         function()
            local parts = {}
            local part
            local left
            local length
            local header
            local _
            local fd = sock:getfd()
            assert(fd > -1)
            return ev.IO.new(
               function(loop,read_io)
                  while true do
                     if not header or #header < 4 then
                        local err,sub 
                        header,err,sub = sock:receive(4,header)
                        if err then
                           if err == 'timeout' then
                              header = sub
                              return                                    
                           else
                              if err ~= 'closed' then
                                 log('ERROR','unknown socket error',err)
                              end
                              read_io:stop(loop)
                              sock:shutdown()
                              sock:close()
                              on_close(wrapped)
                              return                           
                           end
                        end
                        if #header == 4 then
                           _,left = header:unpack('>I')
                           if left == 0 then
--                              print('on message',#parts,tconcat(parts))
                              on_message(parts,wrapped)
                              parts = {}
                              part = nil
                              left = nil
                              length = nil
                              header = nil
                           else
                              length = left
                           end
                        end
                     end
                     if length then
                        if not part or #part ~= length then
                           local err,sub
                           part,err,sub = sock:receive(length,part)
                           if err then
                              if err == 'timeout' then
                                 part = sub
                                 left = length - #part
                                 return
                              else 
                                 if err ~= 'closed' then
                                    log('ERROR','unknown socket error',err)
                                 end
                                 read_io:stop(loop)
                                 sock:shutdown()
                                 sock:close()
                                 on_close(wrapped)                                
                                 return
                              end
                           end
                           if #part == length then
                              tinsert(parts,part)
                              part = nil
                              left = nil
                              length = nil
                              header = nil
                           end
                        end
                     end -- if length
                  end -- while
               end,
         fd,
         ev.READ)
         end
      return wrapped
   end



local listener = 
   function(port,on_connect)
      local sock = assert(socket.bind('*',port))
      sock:settimeout(0)
      local fd = sock:getfd()
      assert(fd > -1)
      local listen_io = ev.IO.new(
         function(loop,accept_io)
            local client = assert(sock:accept())         
            local wrapped = wrap_async(client)
            wrapped:read_io():start(loop)
            on_connect(wrapped)
         end,
         fd,
         ev.READ)
      return {
         io = listen_io
      }
   end

return {
   listener = listener,
   wrap_async = wrap_async,
   wrap_sync = wrap_sync
}

