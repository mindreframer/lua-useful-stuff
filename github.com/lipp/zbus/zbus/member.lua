local ev = require'ev'
local assert = assert
local table = table
local pairs = pairs
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
local zconfig = require'zbus.config'
local socket = require'socket'
local wrap_async = require'zbus.socket'.wrap_async
local wrap_sync = require'zbus.socket'.wrap_sync

module('zbus.member')

new = 
   function(user)
      local config = zconfig.member(user)
      local self = {}        
      local log = config.log
      local serialize_args = config.serialize.args
      local serialize_result = config.serialize.result
      local serialize_err = config.serialize.err
      local make_zerr = config.make_err
      local unserialize_args = config.unserialize.args
      local unserialize_result = config.unserialize.result
      local unserialize_err = config.unserialize.err
      self.ev_loop = config.ev_loop or ev.Loop.default

      self.broker_call = 
         function(self,args)
            log('broker_call',args[1])
            if not self.registry then
               local sock = socket.connect(config.broker.ip,config.broker.registry_port)
               if not sock then
                  error('could not connect to zbusd registry on '..config.broker.ip..':'..config.broker.registry_port,4)
               end
               self.registry = wrap_sync(sock)
            end
            tinsert(args,config.name)
            self.registry:send_message(args)
            local resp = self.registry:receive_message()
            if #resp > 1 then
               error('broker call "'..tconcat(args,',')..'" failed:'..resp[2],2)
            else
               return resp[1]
            end
         end

      self.listen_init = 
         function(self)        
            assert(not self.listen)
            self.listen_port = self:broker_call{'listen_open'}
            self.listen = wrap_async(socket.connect(config.broker.ip,self.listen_port))
            self.listen:on_message(self.dispatch_notifications)
            self.listen_callbacks = {}          
         end

      self.listen_add = 
         function(self,expr,func)
            assert(expr,func)
            if not self.listen then
               self:listen_init()
            end
            self:broker_call{'listen_add',self.listen_port,expr}
            self.listen_callbacks[expr] = func
         end
      
      self.listen_remove = 
         function(self,expr)
            assert(expr and self.listen_callbacks and self.listen_callbacks[expr])
            self:broker_call{'listen_remove',self.listen_port,expr}
            self.listen_callbacks[expr] = nil            
         end
      
      self.replier_init = 
         function(self)
            assert(not self.rep)
            self.rep_port = self:broker_call{'replier_open'}
            self.rep = wrap_async(socket.connect(config.broker.ip,self.rep_port))           
            self.reply_callbacks = {}
            self.rep:on_message(self.dispatch_request)
         end
      
      self.replier_add = 
         function(self,expr,func,async)
            assert(expr,func) -- async is optional
            if not self.rep then
               self:replier_init()
            end
            self:broker_call{'replier_add',self.rep_port,expr}
            self.reply_callbacks[expr] = {
               func = func,
               async = async
            }            
         end

      self.replier_remove = 
         function(self,expr)
            assert(expr and self.reply_callbacks and self.reply_callbacks[expr])
            self:broker_call{'replier_remove',self.rep_port,expr}
            self.reply_callbacks[expr] = nil            
         end

      local reply_callbacks
      local rep
      self.dispatch_request = 
         function(request)
            rep = rep or self.rep
            reply_callbacks = reply_callbacks or self.reply_callbacks
            local more 
            local rid = request[1]
            local expr = request[2]
            local method = request[3]
            local arguments = request[4]
            local on_success = 
               function(...)
                  rep:send_message{rid,serialize_result(...)}
               end
            local on_error = 
               function(err)
                  rep:send_message{rid,'x',serialize_err(err)}
               end        
            local result 
               local cb = reply_callbacks[expr]
               if cb then
                  if cb.async then
                     result = {pcall(cb.func,
                                     method,
                                     on_success,
                                     on_error,
                                     unserialize_args(arguments))}
                  else
                     result = {pcall(cb.func,
                                     method,
                                     unserialize_args(arguments))}
                     if result[1] then 
                        on_success(unpack(result,2))
                        return
                     end
                  end
                  if not result[1] then 
                     on_error(result[2])
                  end         
               else
                  on_error('method '..method..' not found')
               end
            end

      local listen
      local listen_callbacks
      self.dispatch_notifications = 
         function(notifications)
            listen = listen or self.listen
            for i=1,#notifications,3 do
               local expr = notifications[i]
               local topic = notifications[i+1]
               local arguments = notifications[i+2]
               listen_callbacks = listen_callbacks or self.listen_callbacks
               local cb = listen_callbacks[expr]
               -- could be removed in the meantime
               if cb then
                  local ok,err = pcall(cb,topic,more,unserialize_args(arguments))
                  if not ok then
                     log('dispatch_notifications callback failed',expr,err)
                  end
               end
            end
         end
      
      self.notify = 
         function(self,topic,...)
            self:notify_more(topic,false,...)
         end

      local notifications = {}      
      self.flush_notifications = 
         function(self)
         self.notify_sock:send_message(notifications)
         notifications = {}
         end

      self.notify_more = 
         function(self,topic,more,...)
            if not self.notify_sock then               
               self.notify_sock = wrap_sync(socket.connect(config.broker.ip,config.broker.notify_port))
            end
            tinsert(notifications,topic)
            tinsert(notifications,serialize_args(...))            
            if not more then
               self.notify_sock:send_message(notifications)
               notifications = {}
            end
         end

         
      
      
      self.close = 
         function(self)        
            if self.listen then
               self:broker_call{'listen_close',self.listen_port}
            end
            if self.rep then
               self:broker_call{'replier_close',self.rep_port}
            end
            if self.notify_sock then 
               self.notify_sock:close() 
            end
            if self.listen then 
               self.listen:close() 
            end
            if self.rep then 
               self.rep:close() 
            end
            if self.registry then 
               self.registry:close() 
            end
            if self.rpc_sock then 
               self.rpc_sock:close()
            end
         end

      self.reply_io = 
         function(self)
            if not self.rep then self:replier_init() end
            return self.rep:read_io()
         end

      self.listen_io = 
         function(self)
            if not self.listen then self:listen_init() end
            return self.listen:read_io()
         end

      local rpc_sock = 
         function()
            if not self.rpc_sock then
               local sock = socket.connect(config.broker.ip,config.broker.rpc_port)
               if not sock then
                  error('could not connect to zbusd rpc sock on '..config.broker.ip..':'..config.broker.rpc_port,4)
               end
               self.rpc_sock = wrap_sync(sock)               
            end
            return self.rpc_sock
         end

      self.call = 
         function(self,method,...)
            assert(method)
            local sock = rpc_sock()
            sock:send_message{
               method,
               serialize_args(...)
            }

            local resp = sock:receive_message()
            if #resp > 1 then
               local err = resp[2]
               if #resp > 2 then     
                  local msg = resp[3]
                  error(make_zerr(err,msg),2)
               else
                  error(unserialize_err(err),2)
               end
            end
            return unserialize_result(resp[1])
         end

      self.call_async = 
         function(self,method,on_success,on_error,...)
            assert(method)
            local sock = rpc_sock()
            local fd = sock:getfd()
            assert(fd > -1)
            ev.IO.new(
               function(loop,io)
                  io:stop(loop)
                  local resp = sock:receive_message()
                  if #resp > 1 then
                     local err = resp[2]
                     if #resp > 2 then     
                        local msg = resp[3]
                        on_error(make_zerr(err,msg),2)
                     else
                        on_error(unserialize_err(err),2)
                     end
                  end
                  on_success(unserialize_result(resp[1]))
               end,
               fd,
               ev.READ):start(self.ev_loop)
            
            sock:send_message{
               method,
               serialize_args(...)
            }
         end

      self.loop = 
         function(self,options)
            local options = options or {}
            local listen_io = self:listen_io()
            local reply_io = self:reply_io()            
            local loop = self.ev_loop
            local SIGHUP = 1
            local SIGINT = 2
            local SIGKILL = 9
            local SIGTERM = 15	
            local quit = 
               function()
                  if options.exit then
                     options.exit()
                  end
                  if listen_io then listen_io:stop(loop) end
                  if reply_io then reply_io:stop(loop) end
                  if options.ios then
                     for _,io in ipairs(options.ios) do
                        io:stop(loop)
                     end
                  end
                  self:unloop()
                  self:close()
               end      
            local quit_and_exit = 
               function()
                  quit()
                  os.exit()
               end
            ev.Signal.new(quit,SIGHUP):start(loop)
            ev.Signal.new(quit,SIGINT):start(loop)
            ev.Signal.new(quit,SIGKILL):start(loop)
            ev.Signal.new(quit_and_exit,SIGTERM):start(loop)  
            if listen_io then 
            --    log('LISTEN');
               listen_io:start(loop) 
            end
            if reply_io then 
--               log('REPLY');
               reply_io:start(loop) 
            end
            if options.ios then
               for _,io in ipairs(options.ios) do
                  io:start(loop)
               end
            end
            if options.daemonize then
               options.daemonize()
            end
            loop:loop()
            quit()
         end

      self.unloop = 
         function(self)
            self.ev_loop:unloop()
         end
      
      return self
   end

return {
   new = new
}
