package = 'zbus'
version = 'scm-1'
source = {
   url = 'git://github.com/lipp/zbus.git',
}
description = {
   summary = 'A zeromq based message bus in Lua.',
   homepage = 'http://github.com/lipp/zbus',
   license = 'MIT/X11'
}
dependencies = {
   'lua >= 5.1',
   'lua-ev',
   'lpack',
   'lua-cjson >= 1.0'
}
build = {
   type = 'none',
   install = {
      lua = {
         ["zbus.json"] = 'zbus/json.lua',
         ["zbus.init"] = 'zbus/init.lua',
         ["zbus.member"] = 'zbus/member.lua',  
         ["zbus.broker"] = 'zbus/broker.lua',  
         ["zbus.socket"] = 'zbus/socket.lua',  
         ["zbus.config"] = 'zbus/config.lua',  
      },
      bin = {
         ['zbusd.lua'] = 'bin/zbusd.lua',
         ['zbus-websocket-bridge.lua'] = 'bin/zbus-websocket-bridge.lua'
      }
   }
}
