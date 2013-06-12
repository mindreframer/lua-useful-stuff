--------------------------------------------------------------------------------
-- session.lua: webservice database handlers for admin sessions
-- This file is a part of pk-admin library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------
--
-- WARNING: To be used inside call().
--
-- TODO: Do NOT hardcode primary keys!!!
--
--------------------------------------------------------------------------------

local uuid = require 'uuid'

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

local try,
      fail
      = import 'pk-core/error.lua'
      {
        'try',
        'fail'
      }

local make_loggers
      = import 'pk-core/log.lua'
      {
        'make_loggers'
      }

local update_admin_account_last_info
      = import 'pk-admin/webservice/db/admin_account.lua'
      {
        'update_admin_account_last_info'
      }

--------------------------------------------------------------------------------

local log, dbg, spam, log_error = make_loggers("webservice/db/session", "WDS")

--------------------------------------------------------------------------------

local active_session_postquery = function(etime)
  etime = etime or os.time()

  return [[ AND `etime`>=]] .. etime
end

local inactive_session_postquery = function(etime)
  etime = etime or os.time()

  return [[ AND `etime`<]] .. etime
end

--------------------------------------------------------------------------------

local generate_session_id = function()
  return uuid.new()
end

--------------------------------------------------------------------------------

local is_session_forced = function(session)
  arguments(
      "table", session
    )
  -- Note: admin session can't be forced
  return false
end

--------------------------------------------------------------------------------

local get_active_session_by_account_id = function(api_db, account_id)
  account_id = tonumber(account_id) or account_id -- Allowing strings

  arguments(
      "table", api_db,
      "number", account_id
    )

  -- Note no try()
  return api_db:admin_sessions():get(
      { account_id = account_id },
      active_session_postquery()
    )
end

--------------------------------------------------------------------------------

local delete_expired_session_by_account_id = function(api_db, account_id)
  account_id = tonumber(account_id) or account_id -- Allowing strings

  arguments(
      "table", api_db,
      "number", account_id
    )

  -- Note no try()
  return api_db:admin_sessions():delete(
      { account_id = account_id },
      inactive_session_postquery()
    )
end

--------------------------------------------------------------------------------

-- TODO: ?! Rename? Actually checks max users limit
-- Note that forced sessions are not counted torwards the limit.
local may_create_one_session = function(api_db, max_users_online)
  arguments(
      "table", api_db,
      "number", max_users_online
    )
  assert(max_users_online >= 0)

  -- WARNING: Copy-paste carefully.
  --          The count_online_users() should *include* forced sessions.

  -- Note no try()
  local online_count, err = api_db:admin_sessions():count(
      active_session_postquery()
    )
  if not online_count then
    return nil, "may_create_one_session failed: " .. err
  end

  return (online_count < max_users_online)
end

--------------------------------------------------------------------------------

local try_create_session = function(
    api_db,
    account_id,
    session_ttl,
    request_ip,
    is_forced
  )
  account_id = tonumber(account_id) or account_id -- Allowing strings

  arguments(
      "table", api_db,
      "number", account_id,
      "number", session_ttl,
      "string", request_ip,
      "boolean", is_forced
    )

  assert(session_ttl > 0)
  assert(is_forced == false)

  local session_id = generate_session_id()

  local time = os.time()

  try(
      "INTERNAL_ERROR",
      api_db:admin_sessions():insert
      {
        account_id = account_id;
        session_id = session_id;
        etime = time + session_ttl;
      }
    )

  try(
      "INTERNAL_ERROR",
      update_admin_account_last_info(
          api_db,
          account_id,
          request_ip,
          time
        )
    )

  return session_id
end

--------------------------------------------------------------------------------

-- Returns false if session not found
-- Returns true on success
-- TODO: Update last_ip here and up antikarma if IPs not match.
-- TODO: This, probably, should refuse to work with forced sessions.
local try_check_session_and_renew_ttl = function(
    api_db,
    account_id,
    session_id,
    session_ttl
  )
  arguments(
      "table", api_db,
      "number", account_id,
      "string", session_id,
      "number", session_ttl
    )

  assert(session_ttl > 0)

  local sessions = api_db:admin_sessions()

  local time = os.time()
  local postquery = [[ AND `session_id`=']]
   .. try("INTERNAL_ERROR", sessions:escape(session_id)) .. [[']]
   .. active_session_postquery(time)

  -- TODO: Perhaps select, then update if too little time left
  --       would be faster? Also we would not need count below then.
  local res = try(
      "INTERNAL_ERROR",
      sessions:update(
          {
            account_id = account_id;
            etime = time + session_ttl;
          },
          postquery
        )
    )

  if res == false then
    -- Perhaps we've already updated session this very second?
    -- Update returns false when data is not changed.
    -- TODO: ?! BAD!

    res = try(
        "INTERNAL_ERROR",
        sessions:count(
            [[ AND `account_id`=']] .. account_id .. [[']] .. postquery
          )
      )

    if res > 0 then
      -- Keep this log, it would be needed in production!
      dbg(
          "(not an error) session was already updated this very second",
          account_id, session_id
        )

      assert(res == 1)
      res = true
    else
      res = false
    end
  end

  return res -- May be false
end

--------------------------------------------------------------------------------

local create_session_checker = function(handler_fn)
  arguments(
      "function", handler_fn
    )

  return function(api_context, param)
    local account_id, session_id = param.u, param.s
    if not account_id or not session_id then
      fail("BAD_INPUT", "no account_id or session_id")
    end

    local session_ttl = api_context:admin_config().session_ttl

    local res = try_check_session_and_renew_ttl(
        api_context:db(),
        account_id,
        session_id,
        session_ttl
      )
    if res == false then
      fail("SESSION_EXPIRED", "session expired or not found")
    end

    return handler_fn(api_context, param)
  end
end

--------------------------------------------------------------------------------

return
{
  --[[
  active_session_postquery = active_session_postquery;
  inactive_session_postquery = inactive_session_postquery;
  generate_session_id = generate_session_id;
  try_check_session_and_renew_ttl = try_check_session_and_renew_ttl;
  ]]
  --
  is_admin_session_forced = is_session_forced;
  get_active_admin_session_by_account_id = get_active_session_by_account_id;
  delete_expired_admin_session_by_account_id = delete_expired_session_by_account_id;
  may_create_one_admin_session = may_create_one_session;
  try_create_admin_session = try_create_session;
  --
  -- Note that this name is a part of the apigen contract.
  create_session_checker = create_session_checker;
}
