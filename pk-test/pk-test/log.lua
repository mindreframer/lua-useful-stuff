--------------------------------------------------------------------------------
-- log.lua
-- This file is a part of pk-test library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------

local posix = require "posix"

--------------------------------------------------------------------------------

local LOG_LEVEL,
      wrap_file_sink,
      make_common_logging_config
      = import 'lua-nucleo/log.lua'
      {
        'LOG_LEVEL',
        'wrap_file_sink',
        'make_common_logging_config'
      }

local create_common_logging_system,
      get_current_logsystem_date_microsecond
      = import 'pk-core/log.lua'
      {
        'create_common_logging_system',
        'get_current_logsystem_date_microsecond'
      }

--------------------------------------------------------------------------------

local init_test_logging_system,
      update_test_logging_system_pid
do
  local LOG_LEVEL_CONFIG =
  {
    [LOG_LEVEL.ERROR] = true;
    [LOG_LEVEL.LOG]   = true;
    [LOG_LEVEL.DEBUG] = true;
    [LOG_LEVEL.SPAM]  = true;
  }

  local LOG_MODULE_CONFIG =
  {
    -- Empty; everything is enabled by default.
  }

  local logging_system_id = "{TTTTT} "

  local get_logging_system_id = function()
    return logging_system_id
  end

  update_test_logging_system_pid = function()
    logging_system_id = "{"..("%05d"):format(posix.getpid("pid")).."} "
  end

  init_test_logging_system = function()
    local logging_config = make_common_logging_config(
        LOG_LEVEL_CONFIG,
        LOG_MODULE_CONFIG
      )
    create_common_logging_system(
        get_logging_system_id,
        wrap_file_sink(io.stdout),
        logging_config,
        get_current_logsystem_date_microsecond
      )
  end
end

--------------------------------------------------------------------------------

return
{
  init_test_logging_system = init_test_logging_system;
  update_test_logging_system_pid = update_test_logging_system_pid;
}
