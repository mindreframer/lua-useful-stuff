#!/usr/bin/env lua
local daemonize
for _,opt in ipairs(arg) do
   if opt == '-d' or opt == '--daemon' then      
      local ffi = require'ffi'
      if not ffi then
         print('daemonizing failed: ffi (luajit) is required.')
         os.exit(1)
      end
      ffi.cdef'int daemon(int nochdir, int noclose)'
      daemonize = function()
         assert(ffi.C.daemon(1,1)==0)
      end
   end
end
local broker = require'zbus.broker'.new{
--  reg_url = arg[1],
--  debug = true,
  log = function(...) print('zbusd',...) end
}
broker:loop{daemonize=daemonize}
