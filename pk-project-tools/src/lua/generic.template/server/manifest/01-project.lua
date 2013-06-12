--------------------------------------------------------------------------------
-- manifest/project.lua: project description
#{FILE_HEADER}
--------------------------------------------------------------------------------

-- TODO: DSL-ize!
-- TODO: Validate a-la tools-cli-config (does not harm dsl-isation!!!)

PROJECT_TITLE = "#{PROJECT_NAME}"
title = PROJECT_TITLE

PROJECT_PATH = "${PROJECT_PATH}"
project_path = PROJECT_PATH

local_rocks_repo_path =
  PROJECT_PATH .. "/../deployment/cluster/${CLUSTER_NAME}/rocks"
local_rocks_git_repo_path = PROJECT_PATH .. "/../deployment"

local_cluster_versions_path =
  PROJECT_PATH .. "/../deployment/cluster/${CLUSTER_NAME}/versions"
local_cluster_versions_git_repo_path = PROJECT_PATH .. "/../deployment"

subtrees =
{
  {
    name = "lua-nucleo";
    git = PROJECT_PATH;
    path = "lib/lua-nucleo";
    url = "https://github.com/lua-nucleo/lua-nucleo.git";
    branch = "master";
  };
  {
    name = "lua-aplicado";
    git = PROJECT_PATH;
    path = "lib/lua-aplicado";
    url = "https://github.com/lua-aplicado/lua-aplicado.git";
    branch = "master";
  };
  {
    name = "pk-core";
    git = PROJECT_PATH;
    path = "lib/pk-core";
    url = "gitolite@git.iphonestudio.ru:pk-core.git";
    branch = "master";
  };
--[[BLOCK_START:PK_ADMIN]]
  {
    name = "pk-admin";
    git = PROJECT_PATH;
    path = "lib/pk-admin";
    url = "gitolite@git.iphonestudio.ru:pk-admin.git";
    branch = "master";
  };
--[[BLOCK_END:PK_ADMIN]]
--[[BLOCK_START:PK_WEBSERVICE]]
  {
    name = "pk-webservice";
    git = PROJECT_PATH;
    path = "lib/pk-webservice";
    url = "gitolite@git.iphonestudio.ru:pk-webservice.git";
    branch = "master";
  };
--[[BLOCK_END:PK_WEBSERVICE]]
  {
    name = "pk-engine";
    git = PROJECT_PATH;
    path = "lib/pk-engine";
    url = "gitolite@git.iphonestudio.ru:pk-engine.git";
    branch = "master";
  };
  {
    name = "pk-tools";
    git = PROJECT_PATH;
    path = "lib/pk-tools";
    url = "gitolite@git.iphonestudio.ru:pk-tools.git";
    branch = "master";
  };
  {
    name = "pk-foreign-rocks";
    git = PROJECT_PATH;
    path = "lib/pk-foreign-rocks";
    url = "gitolite@git.iphonestudio.ru:pk-foreign-rocks.git";
    branch = "master";
  };
--[[BLOCK_START:PK_TEST]]
  {
    name = "pk-test";
    git = PROJECT_PATH;
    path = "lib/pk-test";
    url = "gitolite@git.iphonestudio.ru:pk-test.git";
    branch = "master";
  };
--[[BLOCK_END:PK_TEST]]
#{SUBTREE}
--[[BLOCK_START:PK_CORE_JS_LIB]]
  {
    name = "pk-core-js";
    git = PROJECT_PATH;
    path = "lib/pk-core-js";
    url = "gitolite@git.iphonestudio.ru:pk-core-js.git";
    branch = "master";
  };
--[[BLOCK_END:PK_CORE_JS_LIB]]
--[[BLOCK_START:PK_LOGICEDITOR_LIB]]
  {
    name = "pk-logiceditor";
    git = PROJECT_PATH;
    path = "lib/pk-logiceditor";
    url = "gitolite@git.iphonestudio.ru:pk-logiceditor.git";
    branch = "master";
  };
--[[BLOCK_END:PK_LOGICEDITOR_LIB]]
}
