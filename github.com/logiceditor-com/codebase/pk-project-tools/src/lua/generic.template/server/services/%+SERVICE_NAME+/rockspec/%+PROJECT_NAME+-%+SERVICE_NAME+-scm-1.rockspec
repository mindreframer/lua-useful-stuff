package = "#{PROJECT_NAME}-#{SERVICE_NAME}"
version = "scm-1"
source = {
   url = ""
}
description = {
   summary = "#{PROJECT_NAME} #{SERVICE_NAME}",
   homepage = "http://#{PROJECT_DOMAIN}",
   license = "#{LICENSE}",
   maintainer = "#{MAINTAINER}"
}
dependencies = {
   "lua == 5.1",
   "lua-nucleo >= 0.0.1",
   "lua-aplicado >= 0.0.1",
   "pk-core >= 0.0.1",
   "pk-engine >= 0.0.1",
   "wsapi-fcgi >= 1.5-1",
   "luasocket >= 2.0.2",
   "luajson >= 1.2.1"
}
build = {
   type = "none",
   copy_directories = {
      "services/#{SERVICE_NAME}/service";
      "services/#{SERVICE_NAME}/logrotate";
   },
   install = {
      lua = {
         ["#{PROJECT_NAME}-#{SERVICE_NAME}.run"] = "services/#{SERVICE_NAME}/src/#{PROJECT_NAME}/#{SERVICE_NAME}/run.lua";
--[[BLOCK_START:HAS_TASK_PROCESSOR]]
         ["#{PROJECT_NAME}-#{SERVICE_NAME}.tasks"] = "services/#{SERVICE_NAME}/src/#{PROJECT_NAME}/#{SERVICE_NAME}/tasks.lua";
--[[BLOCK_END:HAS_TASK_PROCESSOR]]
      },
      bin = {
         "services/#{SERVICE_NAME}/bin/#{PROJECT_NAME}-#{SERVICE_NAME}.service"
      }
   }
}
