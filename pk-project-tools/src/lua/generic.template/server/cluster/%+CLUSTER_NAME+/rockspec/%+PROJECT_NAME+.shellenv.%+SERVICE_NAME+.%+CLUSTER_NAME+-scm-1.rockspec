package = "#{PROJECT_NAME}.shellenv.#{SERVICE_NAME}.#{CLUSTER_NAME}"
version = "scm-1"
source = {
   url = ""
}
description = {
   summary = "#{PROJECT_NAME} #{SERVICE_NAME} shellenv Configuration for #{CLUSTER_NAME}",
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
          "cluster/#{CLUSTER_NAME}/shellenv/#{SERVICE_NAME}";
   }
}
