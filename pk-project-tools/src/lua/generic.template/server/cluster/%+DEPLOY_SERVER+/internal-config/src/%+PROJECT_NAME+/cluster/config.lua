--------------------------------------------------------------------------------
-- config.lua: basic cluster configuration
#{FILE_HEADER}
--------------------------------------------------------------------------------
-- WARNING: Avoid putting information here at all costs.
--          Use internal-config whenever possible!
--------------------------------------------------------------------------------

return
{
  INTERNAL_CONFIG_HOST = "internal-config#{DEPLOY_SERVER_DOMAIN}";
  INTERNAL_CONFIG_PORT = 80;
  INTERNAL_CONFIG_DEPLOY_HOST = "internal-config-deploy#{DEPLOY_SERVER_DOMAIN}";
  INTERNAL_CONFIG_DEPLOY_PORT = 80;
}
