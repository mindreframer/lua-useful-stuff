--------------------------------------------------------------------------------
-- generate_url_handler_tests.lua: api url handlers tests generator
-- This file is a part of pk-tools library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
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

local make_concatter
      = import 'lua-nucleo/string.lua'
      {
        'make_concatter'
      }

local create_path_to_file,
      write_file
      = import 'lua-aplicado/filesystem.lua'
      {
        'create_path_to_file',
        'write_file'
      }

local walk_tagged_tree
      = import 'pk-core/tagged-tree.lua'
      {
        'walk_tagged_tree'
      }

local make_loggers
      = import 'pk-core/log.lua'
      {
        'make_loggers'
      }

--------------------------------------------------------------------------------

local log, dbg, spam, log_error = make_loggers(
    "generate_url_handler_tests", "GUT"
  )

--------------------------------------------------------------------------------

local generate_url_handler_tests
do
  generate_url_handler_tests = function(schema, out_test_dir_name)
    arguments(
        "table", schema,
        "string", out_test_dir_name
      )

    error("TODO: Implement!")
  end
end

--------------------------------------------------------------------------------

return
{
  generate_url_handler_tests = generate_url_handler_tests;
}
