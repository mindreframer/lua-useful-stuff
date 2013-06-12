package = "#{PROJECT_NAME}.shellenv.#{SERVICE_NAME}.#{DEPLOY_SERVER}"
version = "scm-1"
source = {
   url = ""
}
description = {
   summary = "#{PROJECT_NAME} #{SERVICE_NAME} shellenv Configuration for #{DEPLOY_SERVER}",
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
          "cluster/#{DEPLOY_SERVER}/shellenv/#{SERVICE_NAME}";
   }
}
