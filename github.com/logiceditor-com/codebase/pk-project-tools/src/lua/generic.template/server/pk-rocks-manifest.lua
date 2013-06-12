local ROCKS =
{
  {
    "tools/rockspec/"
 .. "#{PROJECT_NAME}.tools."
 .. "#{PROJECT_NAME}-execute-system-action-scm-1.rockspec";
  };
  {
    generator = { "#{PROJECT_LIBDIR}/rockspec/gen-rockspecs" };
    "#{PROJECT_LIBDIR}/rockspec/#{PROJECT_LIB_ROCK}-scm-1.rockspec";
  };
--[[BLOCK_START:STATIC_NAME]]
  {
    "www/static/#{STATIC_NAME}/rockspec/"
 .. "#{PROJECT_NAME}.www.static.#{STATIC_NAME}-scm-1.rockspec";
  };
--[[BLOCK_END:STATIC_NAME]]
--[[BLOCK_START:API_NAME]]
  {
    "www/#{API_NAME}/rockspec/#{PROJECT_NAME}.#{API_NAME}-scm-1.rockspec";
  };
--[[BLOCK_END:API_NAME]]
--[[BLOCK_START:JOINED_WSAPI]]
  {
    "www/#{JOINED_WSAPI}/rockspec/#{PROJECT_NAME}.#{JOINED_WSAPI}-scm-1.rockspec";
  };
--[[BLOCK_END:JOINED_WSAPI]]
--[[BLOCK_START:SERVICE_NAME]]
  {
    "services/#{SERVICE_NAME}/rockspec/"
 .. "#{PROJECT_NAME}-#{SERVICE_NAME}-scm-1.rockspec";
  };
--[[BLOCK_END:SERVICE_NAME]]
}

--[[BLOCK_START:DEPLOY_SERVER]]
-- cluster #{DEPLOY_SERVER}:
--[[BLOCK_START:DEPLOY_MACHINE]]
-- host #{DEPLOY_MACHINE}:
--[[BLOCK_START:API_NAME]]
  ROCKS[#ROCKS + 1] =
  {
    ["x-cluster-name"] = "#{DEPLOY_SERVER}";
    "cluster/#{DEPLOY_SERVER}/#{DEPLOY_MACHINE}/rockspec/"
 .. "#{PROJECT_NAME}.nginx.#{API_NAME}.#{DEPLOY_SERVER}"
 .. ".#{DEPLOY_MACHINE}-scm-1.rockspec";
  }
--[[BLOCK_END:API_NAME]]
--[[BLOCK_START:JOINED_WSAPI]]
  ROCKS[#ROCKS + 1] =
  {
    ["x-cluster-name"] = "#{DEPLOY_SERVER}";
    "cluster/#{DEPLOY_SERVER}/#{DEPLOY_MACHINE}/rockspec/"
 .. "#{PROJECT_NAME}.nginx.#{JOINED_WSAPI}.#{DEPLOY_SERVER}"
 .. ".#{DEPLOY_MACHINE}-scm-1.rockspec";
  }
--[[BLOCK_END:JOINED_WSAPI]]
--[[BLOCK_START:STATIC_NAME]]
  ROCKS[#ROCKS + 1] =
  {
    ["x-cluster-name"] = "#{DEPLOY_SERVER}";
    "cluster/#{DEPLOY_SERVER}/#{DEPLOY_MACHINE}/rockspec/"
 .. "#{PROJECT_NAME}.nginx-static.#{STATIC_NAME}.#{DEPLOY_SERVER}"
 .. ".#{DEPLOY_MACHINE}-scm-1.rockspec";
  }
--[[BLOCK_END:STATIC_NAME]]
--[[BLOCK_END:DEPLOY_MACHINE]]
--[[BLOCK_END:DEPLOY_SERVER]]

local LOCALHOST_CLUSTERS =
{
--[[BLOCK_START:CLUSTER_NAME]]
  { name = "#{CLUSTER_NAME}" };
--[[BLOCK_END:CLUSTER_NAME]]
}

local DEPLOY_CLUSTERS =
{
--[[BLOCK_START:DEPLOY_SERVER]]
  { name = "#{DEPLOY_SERVER}" };
--[[BLOCK_END:DEPLOY_SERVER]]
}

for i = 1, #DEPLOY_CLUSTERS do
  local name = DEPLOY_CLUSTERS[i].name
--[[BLOCK_START:API_NAME]]
  ROCKS[#ROCKS + 1] =
  {
    ["x-cluster-name"] = name;
    "cluster/" .. name .. "/rockspec/"
 .. "#{PROJECT_NAME}.shellenv.#{API_NAME}." .. name .. "-scm-1.rockspec";
  }
--[[BLOCK_END:API_NAME]]
--[[BLOCK_START:JOINED_WSAPI]]
  ROCKS[#ROCKS + 1] =
  {
    ["x-cluster-name"] = name;
    "cluster/" .. name .. "/rockspec/"
 .. "#{PROJECT_NAME}.shellenv.#{JOINED_WSAPI}." .. name .. "-scm-1.rockspec";
  }
--[[BLOCK_END:JOINED_WSAPI]]
--[[BLOCK_START:SERVICE_NAME]]
  ROCKS[#ROCKS + 1] =
  {
    ["x-cluster-name"] = name;
    "cluster/" .. name .. "/rockspec/"
 .. "#{PROJECT_NAME}.shellenv.#{SERVICE_NAME}." .. name .. "-scm-1.rockspec";
  };
--[[BLOCK_END:SERVICE_NAME]]
  ROCKS[#ROCKS + 1] =
  {
    ["x-cluster-name"] = name;

    "cluster/" .. name .. "/internal-config/rockspec/"
 .. "#{PROJECT_NAME}.internal-config." .. name .. "-scm-1.rockspec";
  }

  ROCKS[#ROCKS + 1] =
  {
    ["x-cluster-name"] = name;

    "cluster/" .. name .. "/internal-config/rockspec/"
 .. "#{PROJECT_NAME}.internal-config-deploy." .. name .. "-scm-1.rockspec";
  }

  ROCKS[#ROCKS + 1] =
  {
    ["x-cluster-name"] = name;

    "cluster/" .. name .. "/internal-config/rockspec/"
 .. "#{PROJECT_NAME}.cluster-config." .. name .. "-scm-1.rockspec";
  }
end

for i = 1, #LOCALHOST_CLUSTERS do
  local name = LOCALHOST_CLUSTERS[i].name
--[[BLOCK_START:API_NAME]]
  ROCKS[#ROCKS + 1] =
  {
    ["x-cluster-name"] = name;
    "cluster/" .. name .. "/localhost/rockspec/"
 .. "#{PROJECT_NAME}.nginx.#{API_NAME}." .. name
 .. ".localhost-scm-1.rockspec";
  }
  ROCKS[#ROCKS + 1] =
  {
    ["x-cluster-name"] = name;
    "cluster/" .. name .. "/rockspec/"
 .. "#{PROJECT_NAME}.shellenv.#{API_NAME}." .. name .. "-scm-1.rockspec";
  }

--[[BLOCK_END:API_NAME]]
--[[BLOCK_START:JOINED_WSAPI]]
  ROCKS[#ROCKS + 1] =
  {
    ["x-cluster-name"] = name;
    "cluster/" .. name .. "/localhost/rockspec/"
 .. "#{PROJECT_NAME}.nginx.#{JOINED_WSAPI}." .. name
 .. ".localhost-scm-1.rockspec";
  }
  ROCKS[#ROCKS + 1] =
  {
    ["x-cluster-name"] = name;
    "cluster/" .. name .. "/rockspec/"
 .. "#{PROJECT_NAME}.shellenv.#{JOINED_WSAPI}." .. name .. "-scm-1.rockspec";
  }

--[[BLOCK_END:JOINED_WSAPI]]
--[[BLOCK_START:SERVICE_NAME]]
  ROCKS[#ROCKS + 1] =
  {
    ["x-cluster-name"] = name;
    "cluster/" .. name .. "/rockspec/"
 .. "#{PROJECT_NAME}.shellenv.#{SERVICE_NAME}." .. name .. "-scm-1.rockspec";
  };
--[[BLOCK_END:SERVICE_NAME]]
--[[BLOCK_START:STATIC_NAME]]
  ROCKS[#ROCKS + 1] =
  {
    ["x-cluster-name"] = name;
    "cluster/" .. name .. "/localhost/rockspec/"
 .. "#{PROJECT_NAME}.nginx-static.#{STATIC_NAME}." .. name
 .. ".localhost-scm-1.rockspec";
  }

--[[BLOCK_END:STATIC_NAME]]
  ROCKS[#ROCKS + 1] =
  {
    ["x-cluster-name"] = name;

    "cluster/" .. name .. "/internal-config/rockspec/"
 .. "#{PROJECT_NAME}.internal-config." .. name .. "-scm-1.rockspec";
  }

  ROCKS[#ROCKS + 1] =
  {
    ["x-cluster-name"] = name;

    "cluster/" .. name .. "/internal-config/rockspec/"
 .. "#{PROJECT_NAME}.internal-config-deploy." .. name .. "-scm-1.rockspec";
  }

  ROCKS[#ROCKS + 1] =
  {
    ["x-cluster-name"] = name;

    "cluster/" .. name .. "/internal-config/rockspec/"
 .. "#{PROJECT_NAME}.cluster-config." .. name .. "-scm-1.rockspec";
  }
end

return
{
  ROCKS = ROCKS;
}
