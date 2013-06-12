package = "#{PROJECT_NAME}.nginx-static.#{STATIC_NAME}.#{CLUSTER_NAME}.localhost"
version = "scm-1"
source = {
   url = "" -- Installable with `luarocks make` only
}
description = {
   summary = "#{PROJECT_NAME} #{STATIC_NAME} static nginx Configuration for #{CLUSTER_NAME}",
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
      "cluster/#{CLUSTER_NAME}/localhost/nginx/#{STATIC_NAME}-static";
   }
}
