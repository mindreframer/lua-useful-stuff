--------------------------------------------------------------------------------
-- billing-lib.lua: apigen configuration
--------------------------------------------------------------------------------
-- Note that PROJECT_PATH is defined in the environment
--------------------------------------------------------------------------------

local file = function(name) return { filename = name } end

local luarocks_show_rock_dir =
  import "lua-aplicado/shell/luarocks.lua"
  {
    "luarocks_show_rock_dir"
  }

local NAME = "pk-webservice"

local EXPORTS_LIST_NAME = PROJECT_PATH
    .. "generated/" .. NAME .. "/code/exports/client_api.lua";

common.PROJECT_PATH = PROJECT_PATH

common.www.application.url = "http://pk-webservice-api/"
common.www.application.api_schema_dir = PROJECT_PATH .. "schema/client_api/"
common.www.application.have_unity_client = false
-- common.www.application.session_checker_file_name = false

common.www.application.db_tables_filename = "pk-webservice/db/tables.lua"
common.www.application.webservice_request_filename = "pk-webservice/webservice/request.lua"

common.www.application.code.exports =
{
  file ("lua-nucleo/code/exports.lua");
  file ("lua-aplicado/code/exports.lua");
  file ("pk-core/code/exports.lua");
  file ("pk-engine/code/exports.lua");
--  TODO: FIXME: real client_api exportlist here
--  file (EXPORTS_LIST_NAME);
}

common.www.application.code.requires =
{
  file ("pk-engine/code/requires.lua");
}

common.www.application.code.globals =
{
  file ("lua-nucleo/code/foreign-globals/luajit2.lua");
  file ("lua-nucleo/code/foreign-globals/lua5_1.lua");
  file ("lua-nucleo/code/globals.lua");
}

common.www.application.generated =
{
  file_root = PROJECT_PATH .. "/generated/";

  api_version_filename = "client_api_version.lua";
  handlers_index_filename = "handlers.lua";
  data_formats_filename = "formats.lua";
  handlers_dir_name = "handlers";

  exports_dir_name = "lib";
  exports_list_name = EXPORTS_LIST_NAME;

  context_extensions_dir_name = "pk-webservice/ext";
  context_extensions_list_name = "pk-webservice/extensions.lua";

  doc_md_filename = PROJECT_PATH .. "doc/client_api.md";
  doc_pdf_filename = PROJECT_PATH .. "doc/client_api.pdf";
  doc_latex_template_filename =
    luarocks_show_rock_dir("pk-tools.apigen.doc.template")
    .. "/" .. "src/doc/template/latex.template";

  base_url_prefix = "/";

  --

  unity_api_filename = "/dev/null";
  test_dir_name = "/dev/null";
}

apigen =
{
  action =
  {
    name = "help";
    param =
    {
      -- No parameters
    };
  };
}
