package = "#{PROJECT_NAME}.nginx.#{JOINED_WSAPI}.#{DEPLOY_SERVER}.#{DEPLOY_MACHINE}"
version = "scm-1"
source = {
   url = "" -- Installable with `luarocks make` only
}
description = {
   summary = "#{PROJECT_NAME} #{JOINED_WSAPI} nginx Configuration for #{DEPLOY_SERVER}.#{DEPLOY_MACHINE}",
   homepage = "http://#{PROJECT_DOMAIN}",
   license = "#{LICENSE}",
   maintainer = "#{MAINTAINER}"
}
supported_platforms = {
   "unix"
}
dependencies = {
}
build = {
   type = "none",
      copy_directories = {
      "cluster/#{DEPLOY_SERVER}/#{DEPLOY_MACHINE}/nginx/#{JOINED_WSAPI}";
      "cluster/#{DEPLOY_SERVER}/logrotate/#{JOINED_WSAPI}";
   }
}
