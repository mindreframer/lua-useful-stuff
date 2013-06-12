--------------------------------------------------------------------------------
-- manifest/clusters/localhost.lua: developer machine pseudo-cluster description
#{FILE_HEADER}
--------------------------------------------------------------------------------

local localhost_config = function(name)
  return
  {
    name = name;
    version_tag_suffix = name;
    rocks_repo_url = local_rocks_repo_path;

    internal_config_host = "#{PROJECT_NAME}-internal-config";
    internal_config_port = 80;
    internal_config_deploy_host = "#{PROJECT_NAME}-internal-config-deploy";
    internal_config_deploy_port = 80;

    machines =
    {
      {
        name = "localhost";
        external_url = "localhost";
        internal_url = "localhost";

        -- TODO: Make sure this works, should result in call to $ hostname.
        node_id = "$(hostname)";

        roles =
        {
          { name = "rocks-repo-localhost" }; -- WARNING: Must be the first
          --
          { name = "cluster-member" };
          { name = "internal-config-deploy" };
          { name = "internal-config" };
--[[BLOCK_START:API_NAME]]
          { name = "#{PROJECT_NAME}-#{API_NAME}" };
--[[BLOCK_END:API_NAME]]
--[[BLOCK_START:JOINED_WSAPI]]
          { name = "#{PROJECT_NAME}-#{JOINED_WSAPI}" };
--[[BLOCK_END:JOINED_WSAPI]]
--[[BLOCK_START:SERVICE_NAME]]
          { name = "#{PROJECT_NAME}-#{SERVICE_NAME}" };
--[[BLOCK_END:SERVICE_NAME]]
--[[BLOCK_START:STATIC_NAME]]
          { name = "#{PROJECT_NAME}-static-#{STATIC_NAME}" };
--[[BLOCK_END:STATIC_NAME]]
--[[BLOCK_START:REDIS_BASE_HOST]]
          { name = "#{REDIS_BASE_HOST}" };
--[[BLOCK_END:REDIS_BASE_HOST]]
--[[BLOCK_START:MYSQL_BASES]]
          { name = "#{MYSQL_BASES}" };
--[[BLOCK_END:MYSQL_BASES]]
--[[BLOCK_START:PK_TEST]]
          { name = "pk-test" };
--[[BLOCK_END:PK_TEST]]
        };
      };
    };
  }
end

clusters = clusters or { }
--[[BLOCK_START:CLUSTER_NAME]]
clusters[#clusters + 1] = localhost_config "#{CLUSTER_NAME}"
--[[BLOCK_END:CLUSTER_NAME]]
-- Add more as needed
