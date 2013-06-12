--------------------------------------------------------------------------------
-- admin_account.lua: webservice database handlers for admin accounts
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

--------------------------------------------------------------------------------

local log, dbg, spam, log_error = make_loggers("webservice/db/admin_account", "WDA")

--------------------------------------------------------------------------------

-- TODO: Get these constants from schema/db.lua!
local MAX_FULLNAME_LENGTH = 256
local MAX_LOGIN_LENGTH = 256
local MAX_PASSWORD_LENGTH = 32
local MAX_EMAIL_LENGTH = 256
local MAX_PHONE_LENGTH = 256

-- Returns account id on success. Nil, err on failure.
local check_account_params = function(
    profile_id,
    login,
    password,
    full_name,
    email,
    phone,
    request_ip
  )
  arguments(
      "number", profile_id,
      "string", login,
      "string", password,
      "string", full_name,
      "string", email,
      "string", phone,
      "string", request_ip
    )

  local login_len = #login
  local password_len = #password
  local full_name_len = #full_name
  local email_len = #email
  local phone_len = #phone

  if login_len == 0 then
    return nil, "empty login"
  elseif password_len == 0 then
    return nil, "empty password"
  elseif full_name_len == 0 then
    return nil, "empty full_name"
  elseif email_len == 0 then
    return nil, "empty email"
  elseif phone_len == 0 then
    return nil, "empty phone"
  end

  if login_len > MAX_LOGIN_LENGTH then
    return nil, "too large login"
  elseif password_len > MAX_PASSWORD_LENGTH then
    return nil, "too large password"
  elseif full_name_len > MAX_FULLNAME_LENGTH then
    return nil, "too large full_name"
  elseif email_len > MAX_EMAIL_LENGTH then
    return nil, "too large email"
  elseif phone_len > MAX_PHONE_LENGTH then
    return nil, "too large phone"
  end

  return true
end

--------------------------------------------------------------------------------

local is_account_banned = function(account)
  arguments(
      "table", account
    )

  return tonumber(account.banned) ~= 0
end

--------------------------------------------------------------------------------

local update_account_last_info = function(
    api_db,
    account_id,
    request_ip,
    time
  )
  account_id = tonumber(account_id) or account_id -- Allowing strings

  arguments(
      "table", api_db,
      "number", account_id,
      "string", request_ip,
      "number", time
    )

  -- Note no try()
  return api_db:admin_accounts():update
  {
    id = account_id;
    last_ip = request_ip;
    access_time = time;
  }
end

--------------------------------------------------------------------------------

local try_ban_account_by_id = function(api_db, account_id)
  arguments(
      "table", api_db,
      "number", account_id
    )

  local res = try(
      "INTERNAL_ERROR",
      api_db:admin_accounts():update
      {
        id = account_id;
        banned = 1;
      }
    )
  if res then
    log("account", account_id, "is now banned")
  else
    -- Non-fatal error
    log_error(
        "ban_account_by_id: account", account_id,
        "is not found or already banned"
      )
  end
end

--------------------------------------------------------------------------------

local try_create_account = function(
    api_db,
    profile_id,
    login,
    password,
    full_name,
    email,
    phone,
    request_ip
  )
  arguments(
      "table",  api_db,
      "number", profile_id,
      "string", login,
      "string", password,
      "string", full_name,
      "string", email,
      "string", phone,
      "string", request_ip
    )

  local account =
  {
    id = nil; -- auto increment
    profile_id = profile_id;
    banned = 0; -- not banned
    login = login;
    password = password;
    full_name = full_name;
    email = email;
    phone = phone;
    reg_time = os.time();
    access_time = 0; -- no last time, never logged in
    last_ip = ""; -- no last ip, never logged in
  }

  local accounts = api_db:admin_accounts()

  try(
      "INTERNAL_ERROR",
      admin_accounts:insert(account)
    )

  local account_id = try("INTERNAL_ERROR", admin_accounts:getlastautoid())

  log("try_create_account: created id", account_id, account)

  return account_id
end

--------------------------------------------------------------------------------

return
{
  check_admin_account_params = check_account_params;
  is_admin_account_banned = is_account_banned;
  update_admin_account_last_info = update_account_last_info;
  try_ban_admin_account_by_id = try_ban_account_by_id;
  try_create_admin_account = try_create_account;
}
