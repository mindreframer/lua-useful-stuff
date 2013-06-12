--------------------------------------------------------------------------------
-- misc.lua: miscellaneous things shared by admin api generators
-- This file is a part of pk-tools library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------

local make_loggers = import 'pk-core/log.lua' { 'make_loggers' }
local log, dbg, spam, log_error = make_loggers("admin-gen/misc", "AGM")

--------------------------------------------------------------------------------

local fill_placeholders
      = import 'lua-nucleo/string.lua'
      {
        'fill_placeholders'
      }

local create_path_to_file,
      read_file,
      write_file
      = import 'lua-aplicado/filesystem.lua'
      {
        'create_path_to_file',
        'read_file',
        'write_file'
      }

--------------------------------------------------------------------------------

local Q = function(str)
  return ("%q"):format(str)
end

local CR = ("\n"):format("")

local NPAD = function(num,pads)
  return ("%." .. pads .. "d"):format(num)
end

--------------------------------------------------------------------------------

local table_contains_game_data
do
  local admin_tables =
  {
--    admin_accounts = true;
--    admin_profiles = true;
--    admin_sessions = true;
--    admin_log = true;
  }

  table_contains_game_data = function(name)
    return admin_tables[name] ~= true
  end
end

--------------------------------------------------------------------------------

local write_file_using_template = function(
    values, filename_out, template_filename
  )
  local template = assert(read_file(template_filename))

  local data_out = fill_placeholders(template, values)

  assert(create_path_to_file(filename_out))
  assert(write_file(filename_out, data_out))
end

--------------------------------------------------------------------------------

return
{
  Q = Q;
  CR = CR;
  NPAD = NPAD;
  table_contains_game_data = table_contains_game_data;
  write_file_using_template =  write_file_using_template;
}
