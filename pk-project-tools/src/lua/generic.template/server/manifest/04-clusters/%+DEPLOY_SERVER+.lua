--------------------------------------------------------------------------------
-- manifest/clusters/#{DEPLOY_SERVER}.lua: #{DEPLOY_SERVER} cluster description
#{FILE_HEADER}
--------------------------------------------------------------------------------

clusters = clusters or { }

clusters[#clusters + 1] =
{
  name = "#{DEPLOY_SERVER}";
  version_tag_suffix = "#{DEPLOY_SERVER}";
--[[BLOCK_START:DEPLOY_SINGLE_MACHINE]]
  rocks_repo_url = "/srv/#{PROJECT_NAME}#{REMOTE_ROOT_DIR}/cluster/#{DEPLOY_SERVER}/rocks";
--[[BLOCK_END:DEPLOY_SINGLE_MACHINE]]
--[[BLOCK_START:DEPLOY_SEVERAL_MACHINES]]
  rocks_repo_url = "http://#{REMOTE_ROCKS_REPO_URL}";
--[[BLOCK_END:DEPLOY_SEVERAL_MACHINES]]

  internal_config_host = "internal-config#{DEPLOY_SERVER_DOMAIN}";
  internal_config_port = 80;
  internal_config_deploy_host = "internal-config-deploy#{DEPLOY_SERVER_DOMAIN}";
  internal_config_deploy_port = 80;

  machines =
  {
--[[BLOCK_START:DEPLOY_SINGLE_MACHINE]]
    {
      name = "#{DEPLOY_MACHINE}";
      external_url = "#{DEPLOY_SERVER}";
      internal_url = "localhost";

      -- TODO: Make sure this works, should result in call to $ hostname.
      node_id = "$(hostname)";

      roles =
      {
        { name = "rocks-repo-release-#{DEPLOY_SERVER}" }; -- WARNING: Must be the first
        --
        { name = "cluster-member" }; -- WARNING: Must be installed on each host
        --
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
      };
    };
--[[BLOCK_END:DEPLOY_SINGLE_MACHINE]]
--[[BLOCK_START:DEPLOY_SEVERAL_MACHINES]]
--[[BLOCK_START:DEPLOY_MACHINE]]
    {
      name = "#{DEPLOY_MACHINE}"; -- #{ABOUT_MACHINE}

      external_url = "#{DEPLOY_MACHINE_EXTERNAL_URL}";
      internal_url = "#{DEPLOY_MACHINE_INTERNAL_URL}";

      node_id = "$(hostname)";

      roles =
      {
--[[BLOCK_START:ROOT_DEPLOYMENT_MACHINE]]
        { name = "rocks-repo-release-#{DEPLOY_SERVER}" };
--[[BLOCK_END:ROOT_DEPLOYMENT_MACHINE]]
        { name = "cluster-member" };
--[[BLOCK_START:ROLE_NAME]]
        { name = "#{ROLE_NAME}" };
--[[BLOCK_END:ROLE_NAME]]
      };
    };
--[[BLOCK_END:DEPLOY_MACHINE]]
--[[BLOCK_END:DEPLOY_SEVERAL_MACHINES]]
  };
}

-- Add more as needed
