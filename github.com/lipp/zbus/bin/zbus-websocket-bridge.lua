#!/usr/bin/env lua
local cjson = require'cjson'
local tinsert = table.insert
local ev = require'ev'
local websockets = require'websockets'
local ws_ios = {}
local context = nil
local log = 
   function(...)
      print('zbus-websocket-bridge',...)
   end
local zm = require'zbus.member'
local zbus_config = require'zbus.json'
zbus_config.name = 'websocket-bridge'
zbus_config.ev_loop = ev.Loop.default
zbus_config.exit = 
   function()
      for fd,io in pairs(ws_ios) do
	 io:stop(ev.Loop.default)
      end
      context:destroy()
   end
local zm = zm.new(zbus_config)
local clients = 0

context = websockets.context{
   port = arg[2] or 8002,
   on_add_fd = 
      function(fd)	
	 local io = ev.IO.new(
	    function()
	       context:service(0)
	    end,fd,ev.READ)
	 ws_ios[fd] = io
	 io:start(ev.Loop.default)
      end,
   on_del_fd = 
      function(fd)
	 ws_ios[fd]:stop(ev.Loop.default)
	 ws_ios[fd] = nil
      end,
   protocols = {
      ['zbus-call'] =
         function(ws)	  
            ws:on_receive(
      	       function(ws,data)
		  local req = cjson.decode(data)
		  local resp = {id=req.id}
		  local result = {pcall(zm.call,zm,req.method,unpack(req.params))}
		  if result[1] then 
		     table.remove(result,1);
		     resp.result = result
		  else
		     resp.error = result[2]
		  end
      		  ws:write(cjson.encode(resp),websockets.WRITE_TEXT)
      	       end)
         end,
      ['zbus-notification'] =
         function(ws)
           local match_all = '.*'
	    if clients == 0 then
	       local notifications = {}
	       log('listen to jet')
	       zm:listen_add(
		  match_all,
		  function(topic,more,...)
		     tinsert(notifications,{
				topic = topic,
				data = {...}
			     })
		     if not more then
			context:broadcast('zbus-notification',
					  cjson.encode(notifications))
			notifications = {}
		     end
		  end)	       
	    end
	    clients = clients + 1
	    ws:on_broadcast(websockets.WRITE_TEXT)
	    ws:on_closed(function()
			   clients = clients - 1
			   if clients == 0 then
			      log('unlisten to jet')
			      zm:listen_remove(match_all)
			   end
			end)
         end
   }
}

zm:loop()


