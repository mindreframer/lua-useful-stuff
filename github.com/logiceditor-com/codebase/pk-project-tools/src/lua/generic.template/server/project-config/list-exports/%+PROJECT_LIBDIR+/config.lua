--------------------------------------------------------------------------------
-- project-config-defaults.lua: project configuration defaults
#{FILE_HEADER}
--------------------------------------------------------------------------------
-- See format in tools-lib/project-config-schema.lua
-- Note that PROJECT_PATH is defined in the environment
--------------------------------------------------------------------------------

common.PROJECT_PATH = PROJECT_PATH
common.file_header = [[
#{FILE_HEADER}
]]
common.exports =
{
    exports_dir = PROJECT_PATH .. "/#{PROJECT_LIBDIR}/";
    profiles_dir = PROJECT_PATH .. "/project-config/list-exports/#{PROJECT_LIBDIR}/";

    sources =
    {
      {
        sources_dir = PROJECT_PATH .. "#{PROJECT_LIBDIR}/generated/";
        root_dir_only = "#{PROJECT_LIBDIR}/lib/";
        profile_filename = "profiles.lua";
        out_filename = "code/exports.lua";
        file_header = common.file_header;
      };
      {
        sources_dir = PROJECT_PATH .. "#{PROJECT_LIBDIR}/generated/";
        root_dir_only = "#{PROJECT_LIBDIR}/ext/";
        profile_filename = "profiles.lua";
        out_filename = "code/extensions.lua";
        file_header = common.file_header;
      };
    };
}

common.db.schema_filename = "/dev/null" --"../backoffice/database/schema/db.lua"
common.db.changes_dir = "/dev/null" --"../backoffice/database/changes/"
common.db.tables_filename = "/dev/null" --"../backoffice/database/tables/tables.lua"
common.db.tables_test_data_filename = "/dev/null" --"../backoffice/database/tables/tables-test-data.lua"

common.internal_config.production.host = "#{PROJECT_NAME}-internal-config"
common.internal_config.deploy.host = "#{PROJECT_NAME}-internal-config-deploy"
common.www.game.url = "http://." -- TODO: ?!
common.www.admin.url = "/dev/null"
common.resources.dir = "/dev/null" -- TODO: ?!

--

apigen.mode = "game"

common.www.admin.enabled = false
common.www.admin.api_schema_dir = "/dev/null"
common.www.admin.project_specific_data_filename = "/dev/null"

common.www.game.generated =
{
  file_root = PROJECT_PATH .. "/generated/";
  api_version_filename = "client_api_version.lua";
  handlers_index_filename = "handlers.lua";
  data_formats_filename = "formats.lua";
  handlers_dir_name = "handlers";
  exports_dir_name = "#{PROJECT_LIBDIR}/lib";
  exports_list_name = PROJECT_PATH .. "/tools/schema/code/exports/client_api.lua";
  base_url_prefix = "/";
  unity_api_filename = "/dev/null"; -- No Unity API
  test_dir_name = PROJECT_PATH .. "/test/cases/client-generated";
  doc_latex_template_filename
    = PROJECT_PATH .. "/tools/schema/client_api/doc/latex.template";
  doc_md_filename = PROJECT_PATH .. "/doc/client_api.md";
  doc_pdf_filename = PROJECT_PATH .. "/doc/client_api.pdf";
}

common.www.admin.generated =
{
  file_root = "/dev/null";
  api_version_filename = "/dev/null";
  handlers_index_filename = "/dev/null";
  data_formats_filename = "/dev/null";
  handlers_dir_name = "/dev/null";
  exports_dir_name = "/dev/null";
  exports_list_name = "/dev/null";
  base_url_prefix = "/dev/null";
  unity_api_filename = "/dev/null";
  test_dir_name = "/dev/null";
  doc_latex_template_filename = "/dev/null";
  doc_md_filename = "/dev/null";
  doc_pdf_filename = "/dev/null";
}

list_exports =
{
  action =
  {
    name = "list-all";
    param =
    {
      -- No parameters
    };
  };
}
