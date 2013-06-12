--------------------------------------------------------------------------------
-- run.lua: client API handlers and tests generator
-- This file is a part of pk-tools library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------

local math = math
local os = os
local io = io
local table = table

local assert, unpack
    = assert, unpack

--------------------------------------------------------------------------------

local lfs = require 'lfs'

--------------------------------------------------------------------------------

local arguments,
      optional_arguments,
      method_arguments,
      eat_true
      = import 'lua-nucleo/args.lua'
      {
        'arguments',
        'optional_arguments',
        'method_arguments',
        'eat_true'
      }

local is_table
      = import 'lua-nucleo/type.lua'
      {
        'is_table'
      }

local assert_is_table,
      assert_is_number,
      assert_is_string
      = import 'lua-nucleo/typeassert.lua'
      {
        'assert_is_table',
        'assert_is_number',
        'assert_is_string'
      }

local empty_table,
      timap,
      tkeys,
      tappend_many,
      tset_many,
      tijoin_many
      = import 'lua-nucleo/table.lua'
      {
        'empty_table',
        'timap',
        'tkeys',
        'tappend_many',
        'tset_many',
        'tijoin_many'
      }

local make_loggers
      = import 'pk-core/log.lua'
      {
        'make_loggers'
      }

local update_file,
      write_file,
      create_path_to_file
      = import 'lua-aplicado/filesystem.lua'
      {
        'update_file',
        'write_file',
        'create_path_to_file'
      }

local remove_recursively
      = import 'lua-aplicado/shell/filesystem.lua'
      {
        'remove_recursively'
      }

local load_schema
      = import 'apigen/load_schema.lua'
      {
        'load_schema'
      }

local validate_schema
      = import 'apigen/validate_schema.lua'
      {
        'validate_schema'
      }

local dump_nodes
      = import 'pk-core/dump_nodes.lua'
      {
        'dump_nodes'
      }

local generate_url_handler_api_version
      = import 'apigen/generate_url_handler_api_version.lua'
      {
        'generate_url_handler_api_version'
      }

local generate_url_handler_data_formats
      = import 'apigen/generate_url_handler_data_formats.lua'
      {
        'generate_url_handler_data_formats'
      }

local generate_url_handler_index
      = import 'apigen/generate_url_handler_index.lua'
      {
        'generate_url_handler_index'
      }

local generate_url_handlers
      = import 'apigen/generate_url_handlers.lua'
      {
        'generate_url_handlers'
      }

local generate_url_handler_tests
      = import 'apigen/generate_url_handler_tests.lua'
      {
        'generate_url_handler_tests'
      }

local generate_unity_client_api
      = import 'apigen/generate_unity_client_api.lua'
      {
        'generate_unity_client_api'
      }

local generate_docs
      = import 'apigen/generate_docs.lua'
      {
        'generate_docs'
      }

local generate_exports
      = import 'apigen/generate_exports.lua'
      {
        'generate_exports'
      }

local generate_exports_list
      = import 'apigen/generate_exports_list.lua'
      {
        'generate_exports_list'
      }

local generate_context_extensions
      = import 'apigen/generate_context_extensions.lua'
      {
        'generate_context_extensions'
      }

local generate_context_extensions_list
      = import 'apigen/generate_context_extensions_list.lua'
      {
        'generate_context_extensions_list'
      }

local load_tools_cli_data_schema,
      load_tools_cli_config,
      print_tools_cli_config_usage,
      freeform_table_value
      = import 'pk-core/tools_cli_config.lua'
      {
        'load_tools_cli_data_schema',
        'load_tools_cli_config',
        'print_tools_cli_config_usage',
        'freeform_table_value'
      }

local tpretty
      = import 'lua-nucleo/tpretty.lua'
      {
        'tpretty'
      }

local create_config_schema
      = import 'apigen/project-config/schema.lua'
      {
        'create_config_schema',
      }

local merge_exports
      = import 'pk-tools/exports.lua'
      {
        'merge_exports'
      }

--------------------------------------------------------------------------------

local log, dbg, spam, log_error = make_loggers("apigen", "AGE")

--------------------------------------------------------------------------------

-- NOTE: Generation requires fixed random seed for consistency
math.randomseed(12345)

--------------------------------------------------------------------------------

-- TODO: This should use lua-aplicado/shell*
local generate_documents = function(
    api,
    latex_template_filename,
    out_doc_md_filename,
    out_doc_pdf_filename,
    keep_tmp
  )
  assert(create_path_to_file(out_doc_md_filename))
  assert(
      write_file(
          out_doc_md_filename,
          generate_docs(api)
        )
    )
  -- NOTE: Markdown2PDF tool is a part of pandoc package
  --       Template file is cloned from `pandoc -D latex`.
  --       Template file enables Russian.
  --       Template file removes \tableofcontents generation
  --[[
  assert(
      os.execute(
          'markdown2pdf'
       .. ' --toc'
       .. ' --template="' .. latex_template_filename .. '"'
       .. ' -o "' .. out_doc_pdf_filename .. '"'
       .. ' "' .. out_doc_md_filename .. '"'
        ) == 0
    )
  --]]

  -- Pandoc can't do indices, so we're running pdflatex manually.

  local posix = require 'posix'
  local tmpdir = "/tmp/pk-apigen-doc-"..posix.getpid().pid

  log("generating pdf in", tmpdir)
  assert(os.execute("mkdir -p '" .. tmpdir .. "'") == 0)

  do
    local out_latex = tmpdir .. "/out.latex"

    log("generating", out_latex)
    assert(
        os.execute(
            "pandoc"
         .. " --standalone"
         .. " --toc"
         .. " --to=latex"
         .. " --template='" .. latex_template_filename .. "'"
         .. " -o '" .. out_latex .. "'"
         .. ' "' .. out_doc_md_filename .. '"'
          ) == 0
      )

    -- TODO: Handle errors just like markdown2pdf does.
    log("running pdflatex to collect data (pass 1)")
    os.execute(
        "cd '" .. tmpdir .. "' >/dev/null && "
     .. "pdflatex"
     .. " -interaction=batchmode"
     .. " -output-directory '" .. tmpdir .. "'"
     .. " '" .. "out.latex" .. "'"
     .. " && cd - >/dev/null"
      )

    log("running makeindex")
    assert(
        os.execute(
            "cd '" .. tmpdir .. "' >/dev/null && "
         .. "makeindex"
         .. " '" .. "out.idx" .. "'"
         .. " && cd - >/dev/null"
          ) == 0
      )

    -- Need second pass to get index into toc
    log("running pdflatex to collect data (pass 2)")
    os.execute(
        "cd '" .. tmpdir .. "' >/dev/null && "
     .. "pdflatex"
     .. " -interaction=batchmode"
     .. " -output-directory '" .. tmpdir .. "'"
     .. " '" .. "out.latex" .. "'"
     .. " && cd - >/dev/null"
      )

    -- TODO: Handle errors just like markdown2pdf does.
    log("generating pdf")
    os.execute(
        "cd '" .. tmpdir .. "' >/dev/null && "
     .. "pdflatex"
     .. " -interaction batchmode"
     .. " -output-directory '" .. tmpdir .. "'"
     .. " '" .. "out.latex" .. "'"
     .. " && cd - >/dev/null"
      )

    log("moving resulting file to", out_doc_pdf_filename)
    assert(
        os.execute(
            "mv"
         .. " '" .. (tmpdir .. "/out.pdf") .. "'"
         .. " '" .. out_doc_pdf_filename .. "'"
          ) == 0
      )
  end

  if not keep_tmp then
    log("removing", tmpdir)
    remove_recursively(tmpdir, true)
  else
    log("NOT removing", tmpdir, "as configured")
  end
end

--------------------------------------------------------------------------------

-- TODO: Ugly?
local get_exports_requires_globals = function(config)
  local known_exports, allowed_requires, allowed_globals

  do
    known_exports = { }

    local filenames = config.exports
    for i = 1, #filenames do
      local filename = filenames[i].filename
      known_exports = merge_exports(known_exports, import(filename)())
    end
  end

  do
    allowed_requires = { }
    local filenames = config.requires
    for i = 1, #filenames do
      local filename = filenames[i].filename
      allowed_requires = tappend_many(
          allowed_requires,
          import(filename)
          {
            'REQUIRE_GLOBALS'
          }
        )
    end
  end

  do
    local data = { }
    local filenames = config.globals
    for i = 1, #filenames do
      local filename = filenames[i].filename
      data = tijoin_many(data, import(filename) { 'GLOBALS' })
    end

    allowed_globals = tset_many(data)
  end

  return known_exports, allowed_requires, allowed_globals
end

--------------------------------------------------------------------------------

local SCHEMA = create_config_schema()

local EXTRA_HELP, CONFIG, ARGS

--------------------------------------------------------------------------------

local ACTIONS = { }

ACTIONS.help = function()
  print_tools_cli_config_usage(EXTRA_HELP, SCHEMA)
end

ACTIONS.check_config = function()
  io.stdout:write("config OK\n")
  io.stdout:flush()
end

ACTIONS.dump_config = function()
  io.stdout:write(tpretty(freeform_table_value(CONFIG), " ", 80), "\n")
  io.stdout:flush()
end

ACTIONS.dump_nodes = function()
  local ACTION_CONFIG = CONFIG.apigen.action.param
  local MODE_CONFIG = CONFIG.common.www.application

  local api_schema_dir = MODE_CONFIG.api_schema_dir

  local out_filename = ACTION_CONFIG.out_filename
  local with_indent = ACTION_CONFIG.with_indent
  local with_names = ACTION_CONFIG.with_names

  local api = load_schema(api_schema_dir)
  -- Note that schema is intentionally not validated

  dump_nodes(
      api,
      out_filename,
      "id",
      "name",
      with_indent,
      with_names
    )

  log("OK")
end

ACTIONS.check = function()
  local ACTION_CONFIG = CONFIG.apigen.action.param
  local MODE_CONFIG = CONFIG.common.www.application

  local known_exports, allowed_requires, allowed_globals
      = get_exports_requires_globals(freeform_table_value(MODE_CONFIG.code))

  local api_schema_dir = MODE_CONFIG.api_schema_dir

  local api = load_schema(api_schema_dir)
  validate_schema(known_exports, allowed_requires, allowed_globals, api)

  log("OK")
end

ACTIONS.dump_urls = function()
  local ACTION_CONFIG = CONFIG.apigen.action.param
  local MODE_CONFIG = CONFIG.common.www.application

  local api_schema_dir = MODE_CONFIG.api_schema_dir

  local out_filename = ACTION_CONFIG.out_filename

  local known_exports, allowed_requires, allowed_globals
      = get_exports_requires_globals(freeform_table_value(MODE_CONFIG.code))

  local api = load_schema(api_schema_dir)
  validate_schema(known_exports, allowed_requires, allowed_globals, api)

  local out = (out_filename == "-")
    and io.stdout
     or assert(io.open(out_filename, "w"))

  -- TODO: Hack. Need to walk tree anyway!
  for i = 1, #api do
    local data = api[i]
    if data.urls then
      for i = 1, #data.urls do
        out:write(data.urls[i], "\n")
      end
    end
  end

  if out ~= io.stdout then
    out:close()
  end
  out = nil

  log("OK")
end

ACTIONS.dump_markdown_docs = function()
  local MODE_CONFIG = CONFIG.common.www.application

  local OUT_CONFIG = MODE_CONFIG.generated
  local api_schema_dir = MODE_CONFIG.api_schema_dir

  local known_exports, allowed_requires, allowed_globals
      = get_exports_requires_globals(freeform_table_value(MODE_CONFIG.code))

  local api = load_schema(api_schema_dir)
  validate_schema(known_exports, allowed_requires, allowed_globals, api)

  io.write(generate_docs(api), "\n")
  io.stdout:flush()

  log("OK")
end

ACTIONS.generate_documents = function()
  local MODE_CONFIG = CONFIG.common.www.application

  local OUT_CONFIG = MODE_CONFIG.generated

  local api_schema_dir = MODE_CONFIG.api_schema_dir

  local latex_template_filename = OUT_CONFIG.doc_latex_template_filename
  local out_doc_md_filename = OUT_CONFIG.doc_md_filename
  local out_doc_pdf_filename = OUT_CONFIG.doc_pdf_filename

  local known_exports, allowed_requires, allowed_globals
      = get_exports_requires_globals(freeform_table_value(MODE_CONFIG.code))

  local api = load_schema(api_schema_dir)
  validate_schema(known_exports, allowed_requires, allowed_globals, api)

  generate_documents(
      api,
      latex_template_filename,
      out_doc_md_filename,
      out_doc_pdf_filename,
      CONFIG.apigen.keep_tmp
    )

  log("OK")
end

ACTIONS.update_exports = function()
  local MODE_CONFIG = CONFIG.common.www.application

  local OUT_CONFIG = MODE_CONFIG.generated

  local api_schema_dir = MODE_CONFIG.api_schema_dir
  local out_file_root = OUT_CONFIG.file_root
  local out_exports_dir_name = OUT_CONFIG.exports_dir_name
  local out_exports_list_name = OUT_CONFIG.exports_list_name
  local file_header = MODE_CONFIG.file_header

  local known_exports, allowed_requires, allowed_globals
      = get_exports_requires_globals(freeform_table_value(MODE_CONFIG.code))

  local api = load_schema(api_schema_dir)
  validate_schema(known_exports, allowed_requires, allowed_globals, api)

  generate_exports_list(
      api,
      out_exports_list_name,
      out_file_root,
      out_exports_dir_name,
      file_header
    )
  generate_exports(
      api, out_file_root, out_exports_dir_name,
      known_exports, allowed_requires, allowed_globals, file_header
    )

  log("OK")
end

ACTIONS.update_context_extensions = function()
  local MODE_CONFIG = CONFIG.common.www.application

  local OUT_CONFIG = MODE_CONFIG.generated

  local api_schema_dir = MODE_CONFIG.api_schema_dir
  local out_file_root = OUT_CONFIG.file_root
  local out_context_extensions_dir_name = OUT_CONFIG.context_extensions_dir_name
  local out_context_extensions_list_name
    = OUT_CONFIG.context_extensions_list_name
  local file_header = MODE_CONFIG.file_header

  local known_exports, allowed_requires, allowed_globals
      = get_exports_requires_globals(freeform_table_value(MODE_CONFIG.code))

  local api = load_schema(api_schema_dir)
  validate_schema(known_exports, allowed_requires, allowed_globals, api)

  generate_context_extensions_list(
      api,
      out_context_extensions_list_name,
      out_file_root,
      out_context_extensions_dir_name,
      file_header
    )
  generate_context_extensions(
      api, out_file_root, out_context_extensions_dir_name,
      known_exports, allowed_requires, allowed_globals, file_header
    )

  log("OK")
end

ACTIONS.update_handlers = function()
  local MODE_CONFIG = CONFIG.common.www.application

  local OUT_CONFIG = MODE_CONFIG.generated

  local api_schema_dir = MODE_CONFIG.api_schema_dir
  local have_unity_client = MODE_CONFIG.have_unity_client
  local file_header = MODE_CONFIG.file_header

  local out_file_root = OUT_CONFIG.file_root
  local out_api_version_filename = OUT_CONFIG.api_version_filename
  local out_handlers_index_filename = OUT_CONFIG.handlers_index_filename
  local out_data_formats_filename = OUT_CONFIG.data_formats_filename
  local out_handlers_dir_name = OUT_CONFIG.handlers_dir_name
  local out_exports_dir_name = OUT_CONFIG.exports_dir_name
  local out_exports_list_name = OUT_CONFIG.exports_list_name
  local out_context_extensions_dir_name = OUT_CONFIG.context_extensions_dir_name
  local out_context_extensions_list_name
    = OUT_CONFIG.context_extensions_list_name
  local out_base_url_prefix = OUT_CONFIG.base_url_prefix
  local out_unity_api_filename = OUT_CONFIG.unity_api_filename
  local out_test_dir_name = OUT_CONFIG.test_dir_name
  local latex_template_filename = OUT_CONFIG.doc_latex_template_filename
  local out_doc_md_filename = OUT_CONFIG.doc_md_filename
  local out_doc_pdf_filename = OUT_CONFIG.doc_pdf_filename

  -- TODO: Detect obsolete files and fail instead of this!
  log("Removing", out_file_root.."/"..out_handlers_dir_name.."/*")
  remove_recursively(out_file_root .. '/' .. out_handlers_dir_name .. '/*', true)

  local api = load_schema(api_schema_dir)
  -- TODO: URGENT! make validation possible before generate_exports_list
  generate_exports_list(
      api,
      out_exports_list_name,
      out_file_root,
      out_exports_dir_name,
      file_header
    )

  local known_exports, allowed_requires, allowed_globals
      = get_exports_requires_globals(freeform_table_value(MODE_CONFIG.code))

  validate_schema(known_exports, allowed_requires, allowed_globals, api)

  -- Note: unconditionally overriding files.

  assert(create_path_to_file(out_file_root .. out_api_version_filename))
  assert(
      write_file(
          out_file_root .. out_api_version_filename,
          generate_url_handler_api_version(api, file_header)
        )
    )

  assert(create_path_to_file(out_file_root .. out_data_formats_filename))
  assert(
      write_file(
          out_file_root .. out_data_formats_filename,
          generate_url_handler_data_formats(api, file_header)
        )
    )

  local header
  -- TODO: That freeform_table_value is uberhack! Fix tools_cli_config!
  if freeform_table_value(MODE_CONFIG).session_checker_file_name then
    header = [[
local create_session_checker
= import ']] .. MODE_CONFIG.session_checker_file_name .. [['
{
'create_session_checker'
}
]]
  else
    header = [[]]
  end

  local db_tables_filename = MODE_CONFIG.db_tables_filename

  local webservice_request_filename = MODE_CONFIG.webservice_request_filename

  assert(create_path_to_file(out_file_root .. out_handlers_index_filename))
  assert(
      write_file(
          out_file_root .. out_handlers_index_filename,
          generate_url_handler_index(
              api,
              header,
              out_handlers_dir_name,
              out_data_formats_filename,
              db_tables_filename,
              webservice_request_filename,
              out_base_url_prefix,
              file_header
            )
        )
    )

  generate_exports(
      api, out_file_root, out_exports_dir_name,
      known_exports, allowed_requires, allowed_globals, file_header
    )

  generate_context_extensions_list(
      api,
      out_context_extensions_list_name,
      out_file_root,
      out_context_extensions_dir_name,
      file_header
    )
  generate_context_extensions(
      api, out_file_root, out_context_extensions_dir_name,
      known_exports, allowed_requires, allowed_globals, file_header
    )

  generate_url_handlers(
      api, out_file_root, out_handlers_dir_name,
      known_exports, allowed_requires, allowed_globals, file_header
    )

  if have_unity_client then
    assert(create_path_to_file(out_unity_api_filename))
    assert(
        write_file(
            out_unity_api_filename,
            generate_unity_client_api(api)
          )
      )
  end

  -- Note that documents are intentionally not generated to save time

  log_error("TODO: Generate tests!\n")

  log("OK")
end

-- TODO: Generalize copy-paste!
ACTIONS.update_all = function()
  local MODE_CONFIG = CONFIG.common.www.application

  local OUT_CONFIG = MODE_CONFIG.generated

  local api_schema_dir = MODE_CONFIG.api_schema_dir
  local have_unity_client = MODE_CONFIG.have_unity_client
  local file_header = MODE_CONFIG.file_header

  local out_file_root = OUT_CONFIG.file_root
  local out_api_version_filename = OUT_CONFIG.api_version_filename
  local out_handlers_index_filename = OUT_CONFIG.handlers_index_filename
  local out_data_formats_filename = OUT_CONFIG.data_formats_filename
  local out_handlers_dir_name = OUT_CONFIG.handlers_dir_name
  local out_exports_dir_name = OUT_CONFIG.exports_dir_name
  local out_exports_list_name = OUT_CONFIG.exports_list_name
  local out_context_extensions_dir_name = OUT_CONFIG.context_extensions_dir_name
  local out_context_extensions_list_name
    = OUT_CONFIG.context_extensions_list_name
  local out_base_url_prefix = OUT_CONFIG.base_url_prefix
  local out_unity_api_filename = OUT_CONFIG.unity_api_filename
  local out_test_dir_name = OUT_CONFIG.test_dir_name
  local latex_template_filename = OUT_CONFIG.doc_latex_template_filename
  local out_doc_md_filename = OUT_CONFIG.doc_md_filename
  local out_doc_pdf_filename = OUT_CONFIG.doc_pdf_filename

  local known_exports, allowed_requires, allowed_globals
      = get_exports_requires_globals(freeform_table_value(MODE_CONFIG.code))

  -- TODO: Detect obsolete files and fail instead of this!
  log("Removing", out_file_root.."/"..out_handlers_dir_name.."/*")
  remove_recursively(out_file_root .. '/' .. out_handlers_dir_name .. '/*', true)

  local api = load_schema(api_schema_dir)
  validate_schema(known_exports, allowed_requires, allowed_globals, api)
  -- TODO: See update_handlers for hack with generate_exports_list

  -- Note: unconditionally overriding files.

  assert(create_path_to_file(out_file_root .. out_api_version_filename))
  assert(
      write_file(
          out_file_root .. out_api_version_filename,
          generate_url_handler_api_version(api, file_header)
        )
    )

  assert(create_path_to_file(out_file_root .. out_data_formats_filename))
  assert(
      write_file(
          out_file_root .. out_data_formats_filename,
          generate_url_handler_data_formats(api, file_header)
        )
    )

  local header
  -- TODO: That freeform_table_value is uberhack! Fix tools_cli_config!
  if freeform_table_value(MODE_CONFIG).session_checker_file_name then
    header = [[
local create_session_checker
= import ']] .. MODE_CONFIG.session_checker_file_name .. [['
{
'create_session_checker'
}
]]
  else
    header = [[]]
  end

  assert(create_path_to_file(out_file_root .. out_handlers_index_filename))
  assert(
      write_file(
          out_file_root .. out_handlers_index_filename,
          generate_url_handler_index(
              api,
              header,
              out_handlers_dir_name,
              out_data_formats_filename,
              out_base_url_prefix,
              file_header
            )
        )
    )

  generate_exports_list(
      api,
      out_exports_list_name,
      out_file_root,
      out_exports_dir_name,
      file_header
    )
  generate_exports(
      api, out_file_root, out_exports_dir_name,
      known_exports, allowed_requires, allowed_globals, file_header
    )

  generate_context_extensions_list(
      api,
      out_context_extensions_list_name,
      out_file_root,
      out_context_extensions_dir_name,
      file_header
    )
  generate_context_extensions(
      api, out_file_root, out_context_extensions_dir_name,
      known_exports, allowed_requires, allowed_globals, file_header
    )

  generate_url_handlers(
      api, out_file_root, out_handlers_dir_name,
      known_exports, allowed_requires, allowed_globals, file_header
    )

  if have_unity_client then
    assert(create_path_to_file(out_unity_api_filename))
    assert(
        write_file(
            out_unity_api_filename,
            generate_unity_client_api(api)
          )
      )
  end

  generate_documents(
      api,
      latex_template_filename,
      out_doc_md_filename,
      out_doc_pdf_filename,
      CONFIG.apigen.keep_tmp
    )

  log_error("TODO: Generate tests!\n")

  log("OK")
end

--------------------------------------------------------------------------------

EXTRA_HELP = [[

Usage:

  ]] .. arg[0] .. [[ --root=<PROJECT_PATH> <action> [options]

Actions:

  * ]] .. table.concat(tkeys(ACTIONS), "\n  * ") .. [[

]]

--------------------------------------------------------------------------------

local run = function(...)
  CONFIG, ARGS = assert(load_tools_cli_config(
      function(args)
        local keep_tmp = nil
        if args["--keep-tmp"] then
          keep_tmp = true
        end

        return
        {
          PROJECT_PATH = args["--root"];
          apigen =
          {
            keep_tmp = keep_tmp;
            action = { name = args[1] or args["--action"]; };
          };
        }
      end,
      EXTRA_HELP,
      SCHEMA,
      nil,
      nil,
      ...
    ))

  ACTIONS[CONFIG.apigen.action.name]()
end

--------------------------------------------------------------------------------

return
{
  run = run;
}
