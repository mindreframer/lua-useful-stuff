--------------------------------------------------------------------------------
-- tmp_file_system_objects.lua: work with temp files, dirs, etc.
-- This file is a part of pk-test library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------

-- TODO: Write tests and use "/tmp/pk-test" root

local lfs = require 'lfs'

--------------------------------------------------------------------------------

local make_loggers = import 'pk-core/log.lua' { 'make_loggers' }
local log, dbg, spam, log_error = make_loggers("tmp_file_system_objects", "TFS")

--------------------------------------------------------------------------------

local arguments,
      optional_arguments,
      method_arguments
      = import 'lua-nucleo/args.lua'
      {
        'arguments',
        'optional_arguments',
        'method_arguments'
      }

local assert_is_number,
      assert_is_string
      = import 'lua-nucleo/typeassert.lua'
      {
        'assert_is_number',
        'assert_is_string'
      }

--------------------------------------------------------------------------------

local get_temp_dir = function()
  local name = os.tmpname()
  os.remove(name)
  lfs.mkdir(name)
end

local get_temp_filename = function()
  return os.tmpname()
end

--------------------------------------------------------------------------------

return
{
  get_temp_dir = get_temp_dir;
  get_temp_filename = get_temp_filename;
}
