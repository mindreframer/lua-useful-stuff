package = "#{PROJECT_NAME}.tools.#{PROJECT_NAME}-execute-system-action"
version = "scm-1"
source = {
   url = "" -- Can be built with luarocks make only
}
description = {
   summary = "#{PROJECT_NAME}-execute-system-action Tool",
   homepage = "http://#{PROJECT_DOMAIN}",
   license = "#{LICENSE}",
   maintainer = "#{MAINTAINER}"
}
supported_platforms = {
   "unix"
}
dependencies = {
  "lua >= 5.1",
  "pk-engine >= 0.0.1"
}
build = {
   type = "none",
   install = {
      bin = {
         "tools/bin/#{PROJECT_NAME}-execute-system-action"
      }
   }
}
