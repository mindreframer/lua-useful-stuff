local ev = require'ev'
local assert = assert
local table = table
local pairs = pairs
local tostring = tostring
local ipairs = ipairs
local unpack = unpack
local pcall = pcall
local error = error
local print = print
local require = require
local cjson = require'cjson'
local os = require'os'
local tconcat = table.concat
local tinsert = table.insert
local tremove = table.remove
local smatch = string.match
local zconfig = require'zbus.config'
local acceptor = require'zbus.socket'.listener

module('zbus.broker')

local port_pool = 
   function(port_min,port_max)
      local self = {}
      self.free = {}
      self.used = {}
      local i = 0
      for port=port_min,port_max do                
         self.free[i] = tostring(port)
         i = i + 1
      end

      self.get = 
         function(self)
            local port = tremove(self.free,1)
            if port then
               self.used[port] = true
               return port
            else
               error('port pool empty')
            end
         end

      self.release =
         function(self,port)	 
            if self.used[port] then
               self.used[port] = nil
               tinsert(self.free,port)
               return true
            else
               error('invalid port')
            end
         end
      return self
   end

new = 
   function(user)
      local self = {}
      local config = zconfig.broker(user)
      local log = config.log 
      local loop = ev.Loop.default
      self.repliers = {}
      self.listeners = {}
      self.port_pool = port_pool(
         config.port_pool.port_min,
         config.port_pool.port_max
      )

      local smatch = smatch

      local todo = {}
      
      self.registry_calls = {
         replier_open = 
            function()
--               log('replier_open')
               local replier = {}
               local port = self.port_pool:get()
               replier.exps = {}
               replier.acceptor = acceptor(
                  port,
                  function(responder)
--                     log('replier really open')
                     replier.acceptor.io:stop(loop)
                     replier.acceptor = nil
                     self.repliers[port].responder = responder
                     responder:on_message(
                        function(response)
--                           log(tostring(sock)..'<-RPC',tconcat(response))
                           local rid = response[1]
                           local client = todo[rid]
                           if client then
                              todo[rid] = nil
                              tremove(response,1)
                              client:send_message(response)
                              --                     listener.responder:on_message(on_spurious_message)
                           else
                              log('CRITICAL SPURIOUS MESSAGE',tconcat(response))
                           end
                        end)

--                     responder:on_message(on_spurious_message)
                     responder:on_close(
                        function()
--                           self.repliers[port] = nil
                           self.registry_calls.replier_close(port)
                        end)
                  end)
               replier.acceptor.io:start(loop)
               self.repliers[port] = replier
               return port
            end,

         replier_close = 
            function(replier_port)
               if not replier_port then
                  error('argument error')
               end
               if not self.repliers[replier_port] then
                  return 
--                  error('no replier:'..replier_port)
               end 
               local replier = self.repliers[replier_port]
               if replier then            
                  if replier.acceptor then
                     replier.acceptor.io:stop(loop)
                  end
                  if replier.responder then
                     replier.responder:close()
                  end
                  self.repliers[replier_port] = nil
                  self.port_pool:release(replier_port)
               end
            end,

         replier_add = 
            function(replier_port,exp)
--               log('replier_add',replier_port,exp)
               if not replier_port or not exp then
                  error('argument error')
               end
               if not self.repliers[replier_port] then
                  error('no replier:'..replier_port)
               end
               table.insert(self.repliers[replier_port].exps,exp)              
            end,

         replier_remove = 
            function(replier_port,exp)
               if not replier_port or not exp then
                  error('argument error')
               end          
               local rep = self.repliers[replier_port]
               if not rep then
                  error('no replier:'..replier_port)
               end
               local ok
               for i=1,#rep.exps do
                  if rep.exps[i] == exp then
                     table.remove(rep.exps,i)
                     ok = true
                  end
               end
               if not ok then
                  error('unknown expression:',exp)
               end
            end,

         listen_open = 
            function()
               local listener = {}
               local port = self.port_pool:get()               
--               log('listen','on',port)
               listener.acceptor = acceptor(
                  port,
                  function(client)
                     listener.acceptor.io:stop(loop)
                     listener.acceptor = nil
--                     log('really listening',port)
                     listener.push = client                     
                  end)
               listener.exps = {}
               self.listeners[port] = listener
               listener.acceptor.io:start(loop)
               return port
            end,

         listen_close = 
            function(listen_port)
               if not listen_port then
                  error('argument error')
               end
               if not self.listeners[listen_port] then
                  error('no listener open:'..listen_port)
               end
               if self.listeners[listen_port].push then
                  self.listeners[listen_port].push:close()
               end
               if self.listeners[listen_port].acceptor then
                  listener.acceptor.io:stop(loop)
               end
               self.listeners[listen_port] = nil
               self.port_pool:release(listen_port)
            end,

         listen_add = 
            function(listen_port,exp)
               if not listen_port or not exp then
                  error('argument error')
               end
               if not self.listeners[listen_port] then
                  error('no listener open:'..listen_port)
               end
               table.insert(self.listeners[listen_port].exps,exp)          
            end,

         listen_remove = 
            function(listen_port,exp)
               if not listen_port or not exp then
                  error('arguments error')
               end
               local listener = self.listeners[listen_port]
               if not listener then
                  error('no listener open:'..listen_port)
               end
               for i=1,#listener.exps do
                  if listener.exps[i] == exp then
                     table.remove(listener.exps,i)
                  end
               end        
            end,
      }

      self.registry_socket = acceptor(
         config.broker.registry_port,
         function(client)
            client:on_message(
               function(message)                  
                  local cmd = message[1]
--                  log('REG=>',unpack(message))
                  tremove(message,1)
                  local args = message
                  local ok,ret = pcall(self.registry_calls[cmd],unpack(args))        
                  local resp = {}
                  if ok then
                     resp[1] = ret
                  else
                     resp[1] = 'x' --placeholder, MUST NOT be empty
                     resp[2] = ret
                  end
--                  log('REG<=',cmd,tconcat(resp,' '))
                  client:send_message(resp)
               end)                
         end)

      self.notification_socket = acceptor(
         config.broker.notify_port,
         function(client)
            client:on_message(
               function(notifications)
                  local todos = {}
                  for i=1,#notifications,2 do
                     local topic = notifications[i]
                     local data = notifications[i+1]
                     for url,listener in pairs(self.listeners) do
                        for _,exp in pairs(listener.exps) do
                       --    log('forward_notifications','trying XX',topic)
                           if smatch(topic,exp) then
                              if not todos[listener] then
                                 todos[listener] = {}
                              end
                              tinsert(todos[listener],exp)
                              tinsert(todos[listener],topic)
                              tinsert(todos[listener],data)
                           end
                        end                      
                     end
                  end
                  for listener,notifications in pairs(todos) do
          --           log('NOTIFIYIN',tconcat(notifications))
                     listener.push:send_message(notifications)
                  end                  
               end)
         end)    

      self.method_socket = acceptor(
         config.broker.rpc_port,
         function(client)
            local count = 0
            client:on_message(
               function(message,sock)
--                  log(tostring(sock)..'->RPC',tconcat(message))
                  local method = message[1]
                  local responder,matched_exp
                  local err,err_id                 
                  for url,replier in pairs(self.repliers) do 
                     for _,exp in pairs(replier.exps) do
--                        log('rpc','trying XX',exp,method)--,method:match(exp))
                        if smatch(method,exp) then
  --                         log('rpc','matched',method,exp,url)
                           if responder then
--                              log('rpc','method ambiguous',method,exp,url)
                              err = 'method ambiguous: '..method
                              err_id = 'ERR_AMBIGUOUS'
                           else
                              matched_exp = exp
                              responder = replier.responder
                           end
                        end
                     end
                  end
                  if not responder then
                     err = 'no method for '..method
                     err_id = 'ERR_NOMATCH'
                  end
                  if err then
--                     log('ERROR',err)
                     client:send_message{
                        'x', --placeholder, MUST NOT be empty
                        err_id,
                        err
                     }
                  else
                     local rid = tostring(client)..count
                     count = count + 1
                     todo[rid] = client
                     responder:send_message({  
                                               rid,
                                               matched_exp,
                                               method,
                                               message[2]
                                            })
                  end
               end)
         end)
                  
      self.loop = 
         function(self,options)
            self.method_socket.io:start(loop)
            self.notification_socket.io:start(loop)
            self.registry_socket.io:start(loop)
            if options.daemonize then
               options.daemonize()
            end
            loop:loop()
         end
      
      return self
   end

return {
   new = new
}
