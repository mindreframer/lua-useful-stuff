--------------------------------------------------------------------------------
-- schema.lua: apigen configuration file format
-- This file is a part of pk-tools library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------

local load_tools_cli_data_schema
      = import 'pk-core/tools_cli_config.lua'
      {
        'load_tools_cli_data_schema'
      }

local create_config_schema
do
  local schema_chunk = function()
    cfg:root
    {
--      common_tool_config_schema_chunk();
-- TODO: remove common part, make it to include externally

--------------------------------------------------------------------------------
-- Temporarily added common part

      cfg:node "common"
      {
        cfg:existing_path "PROJECT_PATH";

        cfg:node "www"
        {
          cfg:node "application"
          {
            cfg:url "url";

            cfg:optional_path "session_checker_file_name";
            cfg:string "file_header" { default = "" };
            cfg:path "db_tables_filename" { default = "logic/db/tables.lua" };
            cfg:path "webservice_request_filename"
            {
              default = "logic/webservice/request.lua";
            };

            cfg:existing_path "api_schema_dir";
            cfg:boolean "have_unity_client";

            cfg:node "code"
            {
              cfg:non_empty_ilist "exports"
              {
                cfg:path "filename"; -- TODO: Must be existing_path, append exports_list_name later
              };

              cfg:non_empty_ilist "requires"
              {
                cfg:importable_path "filename";
              };

              cfg:non_empty_ilist "globals"
              {
                cfg:importable_path "filename";
              };
            };

            -- TODO: Refactor this section
            cfg:node "generated"
            {
              cfg:path   "file_root";
              cfg:path   "api_version_filename";
              cfg:path   "handlers_index_filename";
              cfg:path   "data_formats_filename";
              cfg:path   "handlers_dir_name";
              cfg:string "base_url_prefix";
              cfg:path   "unity_api_filename";
              cfg:path   "test_dir_name";
              cfg:existing_path "doc_latex_template_filename";
              cfg:path   "doc_md_filename";
              cfg:path   "doc_pdf_filename";
              cfg:path   "exports_dir_name";
              cfg:path   "exports_list_name";
              cfg:path   "context_extensions_dir_name";
              cfg:path   "context_extensions_list_name";
            };
          };
        };
      };

--------------------------------------------------------------------------------

      cfg:node "apigen"
      {
        cfg:boolean "keep_tmp" { default = false; };

        cfg:variant "action"
        {
          variants =
          {
            ["help"] =
            {
              -- No parameters
            };

            ["dump_nodes"] =
            {
              cfg:path "out_filename" { default = "-" }; -- default stdout
              cfg:boolean "with_indent" { default = true };
              cfg:boolean "with_names" { default = true };
            };

            ["check"] =
            {
              -- No parameters
            };

            ["dump_urls"] =
            {
              -- No parameters
            };

            ["dump_markdown_docs"] =
            {
              -- No parameters
            };

            ["generate_documents"] =
            {
              -- No parameters
            };

            ["update_exports"] =
            {
              -- No parameters
            };

            ["update_context_extensions"] =
            {
              -- No parameters
            };

            ["update_handlers"] =
            {
              -- No parameters
            };

            ["update_all"] =
            {
              -- No parameters
            };
          };
        };
      };
    }
  end

  create_config_schema = function()
    return load_tools_cli_data_schema(
        schema_chunk
      )
  end
end

return
{
  create_config_schema = create_config_schema;
}
