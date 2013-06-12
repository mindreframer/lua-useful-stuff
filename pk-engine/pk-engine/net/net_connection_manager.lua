--------------------------------------------------------------------------------
-- net_connection_manager.lua: luasocket persistent connection manager
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

local is_table,
      is_string
      = import 'lua-nucleo/type.lua'
      {
        'is_table',
        'is_string'
      }

local make_tcp_connector,
      make_domain_socket_connector
      = import 'pk-engine/connector.lua'
      {
        'make_tcp_connector',
        'make_domain_socket_connector'
      }

local make_loggers
      = import 'pk-core/log.lua'
      {
        'make_loggers'
      }

local make_generic_connection_manager
      = import 'pk-engine/generic_connection_manager.lua'
      {
        'make_generic_connection_manager'
      }

local make_persistent_connector
      = import 'pk-engine/net/persistent_connector.lua'
      {
        'make_persistent_connector'
      }

--------------------------------------------------------------------------------

local log, dbg, spam, log_error = make_loggers("net/net_connection_manager", "NCM")

--------------------------------------------------------------------------------

local create_persistent_net_connector = function(info)
  assert(is_table(info) or is_string(info))

  local net_connector
  if is_string(info) then
    net_connector = make_domain_socket_connector(info)
  else
    -- Assuming it is a tcp connection
    net_connector = make_tcp_connector(info.host, info.port)
  end

  return make_persistent_connector(net_connector)
end

local get_net_info_hash = function(info)
  assert(is_table(info) or is_string(info))
  if is_string(info) then
    return "uds:"..info
  end
  return "tcp:"..info.host..":"..info.port
end

local make_net_connection_manager = function()
  return make_generic_connection_manager(
      create_persistent_net_connector,
      get_net_info_hash
    )
end

return
{
  make_net_connection_manager = make_net_connection_manager;
}
