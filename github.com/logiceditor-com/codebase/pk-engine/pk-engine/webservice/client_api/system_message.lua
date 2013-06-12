--------------------------------------------------------------------------------
-- system_message.lua: system message handlers
-- This file is a part of pk-engine library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------
-- TODO: Get rid of redis-based system messages!
--------------------------------------------------------------------------------

local log, dbg, spam, log_error
    = import 'pk-core/log.lua' { 'make_loggers' } (
        "pk-engine/system_message", "SME"
      )

--------------------------------------------------------------------------------

local luabins = require 'luabins'
local zmq = require 'zmq'
require 'zmq.poller'

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

local is_table
      = import 'lua-nucleo/type.lua'
      {
        'is_table'
      }

local tstr
      = import 'lua-nucleo/tstr.lua'
      {
        'tstr'
      }

local tset,
      timap,
      tflip
      = import 'lua-nucleo/table-utils.lua'
      {
        'tset',
        'timap',
        'tflip'
      }

local fill_curly_placeholders
      = import 'lua-nucleo/string.lua'
      {
        'fill_curly_placeholders'
      }

local find_all_files
      = import 'lua-aplicado/filesystem.lua'
      {
        'find_all_files'
      }

local push_task
      = import 'pk-engine/hiredis/system.lua'
      {
        'push_task'
      }

local http_request
      = import 'pk-engine/connector.lua'
      {
        'http_request'
      }

local try,
      fail
      = import 'pk-core/error.lua'
      {
        'try',
        'fail'
      }

--------------------------------------------------------------------------------

local try_send_system_message = function(
    skip_url,
    config_manager,
    redis_manager, -- TODO: Deprecated, remove.
    zmq_context, -- TODO: Must be zmq connection manager instead.
    service_name,
    service_node,
    action_name,
    ...
  )
  arguments(
      -- "string|false", skip_url,
      "table", config_manager,
      "table", redis_manager,
      "userdata", zmq_context,
      "string", service_name,
      -- "string|number", service_node,
      "string", action_name
    )

  spam("try_send_system_message", service_name, service_node, action_name, ...)

  local SERVICE = try(
      "INTERNAL_ERROR",
      config_manager:get_services_config(service_name),
      "unknown service"
    )

  -- TODO: ?! CLI tools need this! (But actions are extensible in run-time!)
  -- try("INTERNAL_ERROR", SERVICE.actions[action_name], "unknown action")

  if not SERVICE.zmq then
    -- Redis-based system messages are deprecated!
    service_node = try(
        "INTERNAL_ERROR",
        tonumber(service_node),
        "service node must be number"
      )

    local NODE_INFO = try(
        "INTERNAL_ERROR",
        try(
            "INTERNAL_ERROR",
            SERVICE.nodes,
            "missing SERVICE.nodes"
          )[service_node], "unknown service node"
      )

    local conn, conn_id = try(
        "INTERNAL_ERROR", redis_manager:acquire_hiredis_connection("system")
      )
    try(
        "INTERNAL_ERROR",
        push_task(
            conn,
            try(
                "INTERNAL_ERROR", SERVICE.prefix, "missing SERVICE.prefix"
              ) .. service_node,
            action_name
          )
      )
    redis_manager:unacquire_hiredis_connection(conn, conn_id)

    if NODE_INFO.url then
      local answer = try(
          "INTERNAL_ERROR",
          http_request(
              (try("INTERNAL_ERROR", NODE_INFO.url, "missing NODE_INFO.url"))
            )
        )

      dbg("system message (redis):", answer)
      return true, answer
    else
      dbg("system message (redis): Silent OK")
      return true
    end
  else -- zmq service
    local zmq_info = SERVICE.zmq
    try("INTERNAL_ERROR", is_table(zmq_info), "bad SERVICE.zmq")
    local urls = zmq_info.urls

    if not urls then
      local protocol = try(
          "INTERNAL_ERROR",
          zmq_info.protocol,
          "missing SERVICE.zmq.protocol"
        )
      local path = try(
          "INTERNAL_ERROR",
          zmq_info.path,
          "missing SERVICE.zmq.path"
        )
      path = fill_curly_placeholders(
          path,
          {
            NODE_ID = service_node;
          }
        ):gsub("/$", "") -- Trim trailing slash (if any)

      local mask = zmq_info.mask

      if protocol ~= "ipc://" or not mask then
        urls = { protocol .. path }
      else
        spam("searching for zmq control socket urls at", path, "mask", mask)
        -- Since we're using ipc://, assuming this is the same machine.
        local filenames = find_all_files(
            path,
            mask,
            { },
            "socket"
          )

        -- Gaah! At least abstract it away!
        spam("opening /proc/net/unix")
        local proc_net_unix_f = try(
            "INTERNAL_ERROR",
            io.open("/proc/net/unix", "r")
          )
        local proc_net_unix = proc_net_unix_f:read("*a")
        proc_net_unix_f:close()
        proc_net_unix_f = nil

        -- Note that we choose to ignore the fact that a process may die
        -- or be spawned anew after we did this check.
        urls = { }
        local num_stale, num_active, num_skipped = 0, 0, 0
        for i = 1, #filenames do
          if proc_net_unix:find(filenames[i], 1, true) then
            -- spam("found active ipc socket:", filenames[i])
            urls[#urls + 1] = protocol .. filenames[i]

            if urls[#urls] == skip_url then
              urls[#urls] = nil
              -- Needed to prevent sending messages to the sender process
              -- itself and thus locking out poller below.
              spam("skipping socket url", skip_url, "as requested")
              num_skipped = num_skipped + 1
            else
              num_active = num_active + 1
            end
          else
            -- dbg("ignoring stale ipc socket:", filenames[i])
            num_stale = num_stale + 1
          end
        end

        dbg(
            "found", num_stale, "stale (ignored) and", num_active,
            "active socket files and also", num_skipped, "skipped files"
          )

        -- spam("found zmq control socket urls", urls)
      end
    end

    table.sort(urls)

    try("INTERNAL_ERROR", #urls > 1, "no zmq socket urls found")

    -- [===[
    spam("connecting zmq sockets")

    local sockets = { }
    for i = 1, #urls do
      local socket_url = urls[i]

      --[[
      -- Assuming poll() below handles this. Keeping the code just in case.
      if socket_url:sub(1, 6) == "ipc://" then
        local res, err = posix.access(socket_url:sub(7), "w")
        if not res then
          -- ZMQ will hang otherwise
          log_error(
              "ignoring socket: no write permissions on `" .. socket_url
              .. "':\n" .. err
              .. "\n\n"
              .. "Hint: if you're running this by hand, "
              .. "run with sudo or from www-data user. "
              .. "Otherwise check manifest file and re-run deploy-rocks."
            )
        end
      else
      ...
      end
      --]]

      local control_socket = try("INTERNAL_ERROR", zmq_context:socket(zmq.PUSH))

    -- Can't be 0 -- or all messages would be discarded on close().
    -- Note that the value is in milliseconds.
    -- Note that 1e3 (1 second) is not that scary:
    -- it will block only on zmq.term(), which is acceptable.
    -- TODO: Make configurable.
      try("INTERNAL_ERROR", control_socket:setopt(zmq.LINGER, 1e3))

      try("INTERNAL_ERROR", control_socket:connect(socket_url))
      sockets[#sockets + 1] = control_socket
    end

    -- TODO: Looks like we would benefit if we will cache this.
    local num_sends = 0
    local num_replies = 0
    local socket_ids = tflip(sockets)
    local results = { }

    do
      local payload = try("INTERNAL_ERROR", luabins.save(action_name, ...))
      for i = 1, #sockets do
        spam("sending zmq system message to", urls[i])
        try(
            "INTERNAL_ERROR",
            sockets[i]:send(payload)
          )
      end
    end

    --[=[
    local alive_sockets = { }

    spam("preparing zmq poller (send)")

    do
      local poller = try("INTERNAL_ERROR", zmq.poller(#sockets))
      do
        local payload = try("INTERNAL_ERROR", luabins.save(action_name, ...))
        local sender = function(sock)
          spam("sending zmq system message to", urls[socket_ids[sock]])
          try(
              "INTERNAL_ERROR",
              sock:send(payload)
            )
          num_sends = num_sends + 1
          alive_sockets[sock] = true
        end

        for i = 1, #sockets do
          poller:add(sockets[i], zmq.POLLOUT, sender)
        end
      end

      spam("polling zmq sockets (send)")

      -- TODO: Make timeout configurable? (Note it is in microseconds)
      poller:poll(0)
    end

    --]=]
--[==[
    spam("preparing zmq poller (recv)")

    do
      local poller = try("INTERNAL_ERROR", zmq.poller(#sockets))
      do
        local payload = try("INTERNAL_ERROR", luabins.save(action_name, ...))
        local receiver = function(sock)
          spam("reading zmq system message reply from", urls[socket_ids[sock]])

          -- TODO: Shouldn't we use poll for recv as well?
          local reply = try("INTERNAL_ERROR", sock:recv())
          local ok, res, err = try("INTERNAL_ERROR", luabins.load(reply))

          dbg("zmq system message reply from", urls[socket_ids[sock]], res, err)

          results[urls[socket_ids[sock]]] = { res, err }

          num_replies = num_replies + 1
        end

        for i = 1, #sockets do
--          if alive_sockets[sockets[i]] then
            poller:add(sockets[i], zmq.POLLIN, receiver)
--[=[          else
            -- Unreliable: above poll seems to register all sockets as alive.
            dbg("stale zmq socket detected:", urls[socket_ids[sock]])
          end--]=]
        end
      end

      spam("polling zmq sockets (recv)")

      -- TODO: Maybe we need timeout here?
      --       Above check does not give 100% guarantee that process
      --       behind the socket is sane and will read something.

      local MAX_TIME = 3 -- In seconds

      local time_start = socket.gettime()
      while num_replies < #sockets do
        local time_now = socket.gettime()
        local time_passed = time_now - time_start
        if time_passed > MAX_TIME then
          log_error("timeout while polling zmq sockets (recv)")
          break
        end
        poller:poll((MAX_TIME - time_passed) * 1e6) -- in microseconds
      end
    end

    log(
        "received", num_replies,
        "replies from", #sockets, "sockets"
      )
--]==]
    spam("closing zmq sockets")

    for i = 1, #sockets do
      sockets[i]:close()
    end

    --log("zmq system message results:", results)
    --]===]
--[===[
    spam("creating zmq PUB socket")

    local control_socket = try("INTERNAL_ERROR", zmq_context:socket(zmq.PUB))

    spam("setting zmq socket LINGER option")

    -- Can't be 0 -- or all messages would be discarded on close().
    -- Note that the value is in milliseconds.
    -- Note that 1e3 (1 second) is not that scary:
    -- it will block only on zmq.term(), which is acceptable.
    -- TODO: Make configurable.
    try("INTERNAL_ERROR", control_socket:setopt(zmq.LINGER, 1e3))

    spam("connecting", #urls, "urls to zmq socket")
    for i = 1, #urls do
      try("INTERNAL_ERROR", control_socket:connect(urls[i]))
    end

    local payload = try("INTERNAL_ERROR", luabins.save(action_name, ...))

    spam("sending payload to zmq socket")

    try(
        "INTERNAL_ERROR",
        control_socket:send(payload)
      )

    spam("closing zmq socket")
    control_socket:close()
    control_socket = nil

    -- TODO: Gather results somehow?
    log("zmq system message results: (Silent OK)")
--]===]
    return true -- No
  end
end

--------------------------------------------------------------------------------

return
{
  try_send_system_message = try_send_system_message;
}
