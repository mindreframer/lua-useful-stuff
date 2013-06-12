--------------------------------------------------------------------------------
-- manifest/subprojects.lua: subprojects description
#{FILE_HEADER}
--------------------------------------------------------------------------------

subprojects =
{
  {
    name = "#{PROJECT_NAME}";
    local_path = PROJECT_PATH;
    rockspec_generator = false;
    provides_rocks_repo =
    {
      {
        name = "lib/pk-foreign-rocks/rocks";
      };
    };
  };
  --
  {
    name = "#{PROJECT_NAME}-deployment";
    local_path = PROJECT_PATH .. "/../deployment";
    rockspec_generator = false;
    provides_rocks_repo =
    {
      {
        name = "rocks/pk";
        pre_deploy_actions =
        {
          {
            tool = "add_rocks_from_pk_rocks_manifest";
            source_repo_name = "#{PROJECT_NAME}";
            local_path = PROJECT_PATH .. "/lib/lua-nucleo/";
            manifest = PROJECT_PATH .. "/lib/lua-nucleo/rockspec/pk-rocks-manifest.lua"
          };
          --
          {
            tool = "add_rocks_from_pk_rocks_manifest";
            source_repo_name = "#{PROJECT_NAME}";
            local_path = PROJECT_PATH .. "/lib/lua-aplicado/";
            manifest = PROJECT_PATH .. "/lib/lua-aplicado/rockspec/pk-rocks-manifest.lua"
          };
          --
          {
            tool = "add_rocks_from_pk_rocks_manifest";
            source_repo_name = "#{PROJECT_NAME}";
            local_path = PROJECT_PATH .. "/lib/pk-core/";
            manifest = PROJECT_PATH .. "/lib/pk-core/rockspec/pk-rocks-manifest.lua"
          };
--[[BLOCK_START:PK_ADMIN]]
          --
          {
            tool = "add_rocks_from_pk_rocks_manifest";
            source_repo_name = "#{PROJECT_NAME}";
            local_path = PROJECT_PATH .. "/lib/pk-admin/";
            manifest = PROJECT_PATH .. "/lib/pk-admin/rockspec/pk-rocks-manifest.lua"
          };
--[[BLOCK_END:PK_ADMIN]]
--[[BLOCK_START:PK_WEBSERVICE]]
          --
          {
            tool = "add_rocks_from_pk_rocks_manifest";
            source_repo_name = "pk-banner-mrx";
            local_path = PROJECT_PATH .. "/lib/pk-webservice/";
            manifest = PROJECT_PATH .. "/lib/pk-webservice/rockspec/pk-rocks-manifest.lua";
          };
--[[BLOCK_END:PK_WEBSERVICE]]
          --
          {
            tool = "add_rocks_from_pk_rocks_manifest";
            source_repo_name = "#{PROJECT_NAME}";
            local_path = PROJECT_PATH .. "/lib/pk-engine/";
            manifest = PROJECT_PATH .. "/lib/pk-engine/rockspec/pk-rocks-manifest.lua"
          };
          --
          {
            tool = "add_rocks_from_pk_rocks_manifest";
            source_repo_name = "#{PROJECT_NAME}";
            local_path = PROJECT_PATH .. "/lib/pk-tools/";
            manifest = PROJECT_PATH .. "/lib/pk-tools/rockspec/pk-rocks-manifest.lua"
          };
--[[BLOCK_START:PK_TEST]]
          --
          {
            tool = "add_rocks_from_pk_rocks_manifest";
            source_repo_name = "#{PROJECT_NAME}";
            local_path = PROJECT_PATH .. "/lib/pk-test/";
            manifest = PROJECT_PATH .. "/lib/pk-test/rockspec/pk-rocks-manifest.lua"
          };
--[[BLOCK_END:PK_TEST]]
        };
      };
      --
      {
        name = "rocks/project";
        pre_deploy_actions =
        {
          {
            tool = "add_rocks_from_pk_rocks_manifest";
            source_repo_name = "#{PROJECT_NAME}";
            local_path = PROJECT_PATH;
            manifest = PROJECT_PATH .. "/pk-rocks-manifest.lua";
            remove_after_pack = true;
          };
        };
      };
    };
  };
}
