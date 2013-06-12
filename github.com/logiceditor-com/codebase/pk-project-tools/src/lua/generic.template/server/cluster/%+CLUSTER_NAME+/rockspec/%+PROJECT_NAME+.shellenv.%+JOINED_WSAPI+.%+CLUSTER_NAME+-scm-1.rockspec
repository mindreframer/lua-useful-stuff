package = "#{PROJECT_NAME}.shellenv.#{JOINED_WSAPI}.#{CLUSTER_NAME}"
version = "scm-1"
source = {
   url = "" -- Installable with `luarocks make` only
}
description = {
   summary = "#{PROJECT_NAME} #{JOINED_WSAPI} shellenv Configuration for #{CLUSTER_NAME}",
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
          "cluster/#{CLUSTER_NAME}/shellenv/#{JOINED_WSAPI}";
   }
}
