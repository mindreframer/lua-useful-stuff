package = "#{PROJECT_NAME}.internal-config.#{CLUSTER_NAME}"
version = "scm-1"
source = {
   url = ""
}
description = {
   summary = "#{PROJECT_NAME} Internal Config",
   homepage = "http://#{PROJECT_DOMAIN}",
   license = "#{LICENSE}",
   maintainer = "#{MAINTAINER}"
}
supported_platforms = {
   "unix"
}
dependencies = {
  -- No dependencies
}
build = {
   type = "none",
   copy_directories = {
      "cluster/#{CLUSTER_NAME}/internal-config/nginx",
      "cluster/#{CLUSTER_NAME}/internal-config/internal-config"
   },
}
