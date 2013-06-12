local assert = assert
local type = type
local pairs = pairs

module('zbus.config')

local base_port = 33325
local registry_port = base_port + 1
local notify_port = base_port + 2
local rpc_port = base_port + 3

local default_broker = {
   log = function() end,
   debug = false,
   broker = {
      interface = '*',
      registry_port = registry_port,
      rpc_port = rpc_port,
      notify_port = notify_port,
   },
   port_pool = {
      port_min = base_port + 4,
      port_max = base_port + 100,
   }
}

local identity = 
   function(a)
      assert(type(a)=='string')
      return a
   end

local make_err = 
   function(code,msg)
      return 'zbus error:'..msg..'('..code..')'
   end

local default_member = {
   make_err = make_err,
   serialize = {
      args = identity,
      result = identity,
      err = identity,
   },
   unserialize = {
      args = identity,
      result = identity,
      err = identity,
   },
   name = 'unnamed-zbus-member',
   log = function() end,
   broker = {
      ip = '127.0.0.1',
      registry_port = registry_port,
      rpc_port = rpc_port,
      notify_port = notify_port,
   }
}

local join_table 
join_table = 
   function(a,b)
      for k,v in pairs(b) do
         if not a[k] then
            a[k] = v
         elseif type(v)=='table' then
            join_table(a[k],v)
         end
      end
      return a
   end

broker = function(user)
         if user then
            return join_table(user,default_broker)
         else
            return default_broker
         end
      end

member = function(user)
         if user then
            return join_table(user,default_member)
         else
            return default_member
         end
      end

return {
   broker = broker,
   member = member
}
