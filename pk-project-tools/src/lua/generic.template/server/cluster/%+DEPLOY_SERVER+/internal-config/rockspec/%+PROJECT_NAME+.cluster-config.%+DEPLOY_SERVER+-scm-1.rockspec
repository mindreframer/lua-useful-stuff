package = "#{PROJECT_NAME}.cluster-config.#{DEPLOY_SERVER}"
version = "scm-1"
source = {
   url = "" -- Use luarocks make
}
description = {
   summary = "#{PROJECT_NAME} Cluster Configuration for #{DEPLOY_SERVER}",
   homepage = "http://#{PROJECT_DOMAIN}",
   license = "#{LICENSE}",
   maintainer = "#{MAINTAINER}"
}
supported_platforms = {
   "unix"
}
dependencies = {
  "lua >= 5.1"
}
build = {
   type = "builtin",
   modules = {
      ["#{PROJECT_NAME}.cluster.config"] = "cluster/#{DEPLOY_SERVER}/internal-config/src/#{PROJECT_NAME}/cluster/config.lua";
   },
}
