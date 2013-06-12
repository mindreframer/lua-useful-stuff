package = "accelerator"
version = "1.0-1"
source = {
   url = "http://github.com/winton/nginx-accelerator"
}
description = {
   summary = "Nginx-level memcaching for fun and profit",
   detailed = [[
      Uses information from Cache-Control headers to memcache responses
      at the nginx level.
   ]],
   homepage = "http://github.com/winton/nginx-accelerator",
   license = "MIT"
}
dependencies = {
   "lua >= 5.1",
   "lua-cjson >= 2.1.0-1"
}
build = {
   type = "builtin",
   modules = {
      ["accelerator"] = "lib/accelerator.lua"
   }
}