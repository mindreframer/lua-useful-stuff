--------------------------------------------------------------------------------
-- persistent_connector.lua
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

local make_loggers
      = import 'pk-core/log.lua'
      {
        'make_loggers'
      }

local make_persistent_connection
      = import 'pk-engine/persistent_connection.lua'
      {
        'make_persistent_connection'
      }

--------------------------------------------------------------------------------

local log, dbg, spam, log_error = make_loggers("net/persistent_connector", "NPC")

--------------------------------------------------------------------------------

local make_persistent_connector
do
  local connect = function(self)
    return make_persistent_connection(self.net_connector_)
  end

  make_persistent_connector = function(net_connector)
    arguments(
        "table", net_connector
      )

    return
    {
      connect = connect;
      --
      net_connector_ = net_connector;
    }
  end
end

return
{
  make_persistent_connector = make_persistent_connector;
}
