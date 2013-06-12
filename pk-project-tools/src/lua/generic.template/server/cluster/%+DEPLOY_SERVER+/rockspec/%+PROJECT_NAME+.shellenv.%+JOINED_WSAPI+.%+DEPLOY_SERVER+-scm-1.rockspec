package = "#{PROJECT_NAME}.shellenv.#{JOINED_WSAPI}.#{DEPLOY_SERVER}"
version = "scm-1"
source = {
   url = "" -- Installable with `luarocks make` only
}
description = {
   summary = "#{PROJECT_NAME} #{JOINED_WSAPI} shellenv Configuration for #{DEPLOY_SERVER}",
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
          "cluster/#{DEPLOY_SERVER}/shellenv/#{JOINED_WSAPI}";
   }
}
