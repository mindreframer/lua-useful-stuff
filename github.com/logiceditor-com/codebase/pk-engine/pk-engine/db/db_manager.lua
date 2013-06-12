--------------------------------------------------------------------------------
-- db_manager.lua: db_connection_manager wrapper that knows about config
-- This file is a part of pk-engine library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
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

local make_db_connection_manager
      = import 'pk-engine/db/db_connection_manager.lua'
      {
        'make_db_connection_manager'
      }

local make_loggers
      = import 'pk-core/log.lua'
      {
        'make_loggers'
      }

--------------------------------------------------------------------------------

local log, dbg, spam, log_error = make_loggers("db/db_manager", "DDM")

--------------------------------------------------------------------------------

local make_db_manager
do
  local acquire_db_connection = function(self, db_name)
    method_arguments(
        self,
        "string", db_name
      )

    local db_info, err = self.config_manager_:get_db_info(db_name)
    if not db_info then
      log_error(
          "acquire_db_connection failed to resolve db_name",
          db_name, ":", err
        )
      return nil, err
    end

    return self.db_connection_manager_:acquire(db_info)
  end

  local unacquire_db_connection = function(self, db_conn, pool_id)
    method_arguments(
        self,
        "userdata", db_conn,
        "string", pool_id
      )

    return self.db_connection_manager_:unacquire(db_conn, pool_id)
  end

  make_db_manager = function(config_manager, db_connection_manager)
    arguments(
        "table", config_manager,
        "table", db_connection_manager
      )

    return
    {
      acquire_db_connection = acquire_db_connection;
      unacquire_db_connection = unacquire_db_connection;
      --
      config_manager_ = config_manager;
      db_connection_manager_ = db_connection_manager;
    }
  end
end

return
{
  make_db_manager = make_db_manager;
}
