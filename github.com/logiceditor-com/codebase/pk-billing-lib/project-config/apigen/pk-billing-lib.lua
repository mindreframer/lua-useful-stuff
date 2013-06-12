--------------------------------------------------------------------------------
-- billing-lib.lua: apigen configuration
-- This file is a part of pk-billing-lib library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------
-- Note that PROJECT_PATH is defined in the environment
--------------------------------------------------------------------------------

local file = function(name) return { filename = name } end

local NAME = "pk-billing-lib"

local EXPORTS_LIST_NAME = PROJECT_PATH
    .. "tmp/" .. NAME .. "/code/exports/client_api.lua"

common.PROJECT_PATH = PROJECT_PATH
common.www.application.file_header = [[
-- This file is a part of pk-billing-lib library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
]]

common.www.application.url = "http://." -- no url used
common.www.application.api_schema_dir = PROJECT_PATH .. "schema/client_api/"
common.www.application.have_unity_client = false

common.www.application.db_tables_filename = "pk-billing-lib/verbatim/db/tables.lua"
common.www.application.webservice_request_filename = "pk-billing-lib/verbatim/webservice/request.lua"

common.www.application.code.exports =
{
  file ("lua-nucleo/code/exports.lua");
  file ("lua-aplicado/code/exports.lua");
  file ("pk-core/code/exports.lua");
  file ("pk-engine/code/exports.lua");
  file ("pk-admin/code/exports.lua");
  --
  file (EXPORTS_LIST_NAME);
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

  exports_dir_name = "pk-billing-lib/lib";
  exports_list_name = EXPORTS_LIST_NAME;

  context_extensions_dir_name = "pk-billing-lib/ext";
  context_extensions_list_name = "pk-billing-lib/extensions/extensions.lua";

  doc_md_filename = PROJECT_PATH .. "doc/pk-billing-lib.md";
  doc_pdf_filename = PROJECT_PATH .. "doc/pk-billing-lib.pdf";
  doc_latex_template_filename = common.www.application.api_schema_dir
    .. "/doc/latex.template";

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
