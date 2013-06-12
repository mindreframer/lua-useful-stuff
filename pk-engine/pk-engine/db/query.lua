--------------------------------------------------------------------------------
-- query.lua: read/modify table in DB
-- This file is a part of pk-engine library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------

local arguments,
      method_arguments,
      optional_arguments
      = import 'lua-nucleo/args.lua'
      {
        'arguments',
        'method_arguments',
        'optional_arguments'
      }

local is_number,
      is_string,
      is_table
      = import 'lua-nucleo/type.lua'
      {
        'is_number',
        'is_string',
        'is_table'
      }

local assert_is_string
      = import 'lua-nucleo/typeassert.lua'
      {
        'assert_is_string'
      }

local make_loggers
      = import 'pk-core/log.lua'
      {
        'make_loggers'
      }

--------------------------------------------------------------------------------

local log, dbg, spam, log_error = make_loggers("query", "QRY")

--------------------------------------------------------------------------------

local get_by_id = function(db_conn, table_name, primary_key, id, post_query)
  post_query = post_query or ''
  arguments(
      "userdata", db_conn,
      "string", table_name,
      "string", primary_key,
      -- "number", id,
      "string", post_query
    )
  assert(is_number(id) or is_string(id), "get_by_id: wrong id type")

  local cursor, err = db_conn:execute(
      [[SELECT * FROM `]]..table_name..[[`]]
   .. [[ WHERE 1 AND `]]..primary_key..[[`=']]..db_conn:escape(id)..[[']]
   .. post_query
   .. [[ LIMIT 1]]
    )
  if not cursor then
    return nil, "get_by_id failed: " .. err
  end

  local row = cursor:fetch({ }, "a")

  cursor:close()

  return row or false
end

-- TODO: Reuse better
local postquery_for_data = function(db_conn, data)
  arguments(
      "userdata", db_conn,
      "table", data
    )

  local query_buf = { }

  for key, value in pairs(data) do
    assert_is_string(key)
    assert(is_number(value) or is_string(value))

    query_buf[#query_buf + 1] = "`" .. key .. "`='"
      .. db_conn:escape(value) .. "'"
  end

  local result = table.concat(query_buf, [[ AND ]])
  if result ~= "" then
    result = [[ AND ]] .. result
  end

  return result
end

local get_by_data = function(db_conn, table_name, primary_key, data, post_query)
  post_query = post_query or ''
  arguments(
      "userdata", db_conn,
      "string", table_name,
      "string", primary_key,
      "table", data,
      "string", post_query
    )

  if next(data) == nil then
    return nil, "get_by_data failed: can't get by empty data"
  end

  local query = [[SELECT * FROM `]]..table_name..[[`]]
   .. [[ WHERE 1 ]]..postquery_for_data(db_conn, data)
   .. post_query
   .. [[ LIMIT 1]]

  -- spam("QUERY:", query)

  local cursor, err = db_conn:execute(query)
  if not cursor then
    log_error("get_by_data failed query:", query)
    log_error("get_by_data failed err:", err)

    return nil, "get_by_data failed: " .. err
  end

  local row = cursor:fetch({ }, "a")

  cursor:close()

  return row or false
end

local insert_one = function(db_conn, table_name, primary_key, row, post_query)
  post_query = post_query or ''
  arguments(
      "userdata", db_conn,
      "string", table_name,
      "string", primary_key, -- Unused
      "table", row,
      "string", post_query
    )

  -- Explicit check for extra argument to prevent copy-paste errors
  if post_query ~= '' then
    -- Note that it is hard to come up with meaningful postquery
    -- for our form of INSERT
    return nil, "insert_one failed: postquery is not supported"
  end

  if next(row) == nil then
    return nil, "insert_one failed: can't insert empty row"
  end

  local keys, values = { }, { }
  for key, value in pairs(row) do
    assert_is_string(key)
    assert(is_number(value) or is_string(value))

    keys[#keys + 1] = "`" .. key .. "`"
    values[#values + 1] = "'" .. db_conn:escape(value) .. "'"
  end

  local num_affected_rows, err = db_conn:execute(
      [[INSERT INTO `]]..table_name..[[`]]
   .. [[ (]]..table.concat(keys, ",")..[[)]]
   .. [[ VALUES (]]..table.concat(values, ",")..[[)]]
   .. post_query
    )

  if not num_affected_rows then
    return nil, "insert_one failed: " .. err
  end

  if num_affected_rows == 1 then
    return true
  end

  -- Note that even 0 rows is unexpected.
  return nil,
         "insert_one failed: unexpected number of affected rows: "
      .. tostring(num_affected_rows)
end

-- Returns false if not found OR data is not changed.
local update_one = function(db_conn, table_name, primary_key, row, post_query)
  post_query = post_query or ''
  arguments(
      "userdata", db_conn,
      "string", table_name,
      "string", primary_key,
      "table", row,
      "string", post_query
    )

  if not row[primary_key] then
    -- NOTE: If you need to do this, you need another function.
    return nil, "update_one failed: can't update row without primary key"
  end

  local query = {  }

  for key, value in pairs(row) do
    assert_is_string(key)
    assert(is_number(value) or is_string(value))

    query[#query + 1] = "`" .. key .. "`='" .. db_conn:escape(value) .. "'"
  end

  local num_affected_rows, err = db_conn:execute(
      [[UPDATE `]]..table_name..[[` SET ]]
   .. table.concat(query, ",")
   .. [[ WHERE 1 AND `]]..primary_key..[[`=']]..db_conn:escape(row[primary_key])..[[']]
   .. post_query
   .. [[ LIMIT 1]]
    )

  if not num_affected_rows then
    return nil, "update_one failed: " .. err
  end

  if num_affected_rows == 0 then
    return false
  end

  if num_affected_rows == 1 then
    return true
  end

  return nil,
         "update_one failed: unexpected number of affected rows: "
      .. tostring(num_affected_rows)
end

-- Private function
local raw_update_or_insert_one = function(
    db_conn,
    table_name,
    primary_key, -- Unused
    keys,
    values,
    updates
  )
  arguments(
      "userdata", db_conn,
      "string", table_name,
      "string", primary_key, -- Unused
      "table",  keys,
      "table",  values,
      "table",  updates
    )

  local query =
      [[INSERT INTO `]] .. table_name .. [[`]]
   .. [[ (]] .. table.concat(keys, ",") .. [[)]]
   .. [[ VALUES (]] .. table.concat(values, ",") .. [[)]]
   .. [[ ON DUPLICATE KEY UPDATE ]] .. table.concat(updates, ", ")

  -- spam("executing", query)

  local num_affected_rows, err = db_conn:execute(query)

  if not num_affected_rows then
    log_error("raw_update_or_insert_one query failed:", err)
    return nil, err
  end

  if num_affected_rows == 1 then
    --spam("INSERTED")
    return true -- Inserted
  end

  if num_affected_rows == 2 then
    --spam("UPDATED")
    return true -- Updated
  end

  if num_affected_rows == 0 then
    --spam("NOOP")
    return false -- Exact match of existing data
  end

  -- Note that even 0 rows is unexpected.
  return nil,
         "unexpected number of affected rows: "
      .. tostring(num_affected_rows)
end

-- Private function
-- TODO: Generalize even more!
local keys_values_updates = function(db_conn, row, keys, values, updates)
  keys = keys or { }
  values = values or { }
  updates = updates or { }

  arguments(
      "table", row,
      "table", keys,
      "table", values,
      "table", updates
    )

  for key, value in pairs(row) do
    assert_is_string(key)
    assert(is_number(value) or is_string(value))

    keys[#keys + 1] = "`" .. key .. "`"
    values[#values + 1] = "'" .. db_conn:escape(value) .. "'"
    updates[#updates + 1] = "`" .. key .. "`=VALUES(`" .. key .. "`)"
  end

  return keys, values, updates
end

-- TODO: Generalize copy-paste
-- TODO: Do not hide auto_increment.
local update_or_insert_one = function(db_conn, table_name, primary_key, row, post_query)
  post_query = post_query or ''
  arguments(
      "userdata", db_conn,
      "string", table_name,
      "string", primary_key, -- Unused
      "table", row,
      "string", post_query
    )

  -- Explicit check for extra argument to prevent copy-paste errors
  if post_query ~= '' then
    -- Note that it is hard to come up with meaningful postquery
    -- for our form of INSERT .. ON DUPLICATE KEY UPDATE
    return nil, "update_or_insert_one failed: postquery is not supported"
  end

  if next(row) == nil then
    return nil, "update_or_insert_one failed: can't insert empty row"
  end

  local keys, values, updates = keys_values_updates(db_conn, row)

  local res, err = raw_update_or_insert_one(
      db_conn,
      table_name,
      primary_key, -- Unused
      keys,
      values,
      updates
    )
  if res == nil then
    return nil, "update_or_insert_one failed: " .. err
  end

  return res -- May be false.
end

-- TODO: Weird! Looks too specialized. Do we need generic version?
-- TODO: Generalize copy-paste
local increment_counter = function(
    db_conn,
    table_name,
    primary_key,
    row,
    counter_field,
    increment, -- May be negative
    default_value,
    post_query
  )
  increment = increment or 1
  default_value = default_value or increment
  post_query = post_query or ''
  arguments(
      "userdata", db_conn,
      "string", table_name,
      "string", primary_key, -- Unused
      "table",  row,
      "string", counter_field,
      "number", increment,
      "number", default_value,
      "string", post_query
    )

  -- Explicit check for extra argument to prevent copy-paste errors
  if post_query ~= '' then
    -- Note that it is hard to come up with meaningful postquery
    -- for our form of INSERT .. ON DUPLICATE KEY UPDATE
    return nil, "increment_counter failed: postquery is not supported"
  end

  if next(row) == nil then
    return nil, "increment_counter failed: can't affect empty row"
  end

  if row[counter_field] ~= nil then
    return nil, "increment_counter failed: ambiguous counter_field value"
  end

  local keys, values, updates = keys_values_updates(db_conn, row)

  keys[#keys + 1] = "`" .. counter_field .. "`"
  values[#values + 1] = "'" .. db_conn:escape(default_value) .. "'"
  updates[#updates + 1] = "`" .. counter_field .. "`=`"
    .. counter_field .. "` + " .. increment

  local res, err = raw_update_or_insert_one(
      db_conn,
      table_name,
      primary_key, -- Unused
      keys,
      values,
      updates
    )
  if res == nil then
    return nil, "increment_counter failed: " .. err
  end

  return res -- May be false.
end

-- TODO: Weird! Looks too specialized. Do we need generic version?
-- TODO: Generalize copy-paste
-- NOTE: Needed for money transactions
local subtract_values_one = function(
    db_conn,
    table_name,
    primary_key,
    row,
    values,
    post_query
  )

  -- TODO: Optimize out table creation
  if not is_table(row) then
    assert(is_number(row) or is_string(row))
    row = { [primary_key] = row }
  end

  post_query = post_query or ''
  arguments(
      "userdata", db_conn,
      "string", table_name,
      "string", primary_key,
      "table",  row,
      "table",  values,
      "string", post_query
    )

  if not row[primary_key] then
    -- NOTE: If you need to do this, you need another function.
    return
      nil,
      "subtract_values_one failed: can't update row without primary key"
  end

  if next(values) == nil then
    return nil, "subtract_values_one failed: nothing to changes"
  end

  local sets, checks = { }, { }

  -- Extra paranoid checks since we're likely to deal with money here.
  for field, value in pairs(values) do
    if row[field] ~= nil then
      return
        nil,
        "subtract_values_one failed: ambiguous value for " .. tostring(field)
    end

    if not tonumber(value) then
      return
        nil,
        "subtract_values_one failed: wrong value type for " .. tostring(field)
    end

    if tonumber(value) < 0 then
      return
        nil,
        "subtract_values_one failed: negative value for " .. tostring(field)
    end

    sets[#sets + 1] = "`" .. field .. "`="
      .. "`" .. field .. "`-" .. tonumber(value)

    -- TODO: Make limit configurable?!
    checks[#checks + 1] = "`" .. field .. "`-" .. tonumber(value) .. ">=0"
  end

  for field, value in pairs(row) do
    checks[#checks + 1] = "`" .. field .. "`='" .. db_conn:escape(value) .. "'"
  end

  local num_affected_rows, err = db_conn:execute(
      [[UPDATE `]]..table_name..[[` SET ]]
   .. table.concat(sets, [[,]])
   .. [[ WHERE 1 AND ]]
   .. table.concat(checks, [[ AND ]])
   .. post_query
   .. [[ LIMIT 1]]
    )

  if not num_affected_rows then
    return nil, "subtract_values_one failed: " .. err
  end

  if num_affected_rows == 0 then
    return false
  end

  if num_affected_rows == 1 then
    return true
  end

  return
    nil,
    "subtract_values_one failed: unexpected number of affected rows: "
    .. tostring(num_affected_rows)
end

-- TODO: Weird! Looks too specialized. Do we need generic version?
-- TODO: Generalize copy-paste
-- NOTE: Needed for money transactions
local add_values_one = function(
    db_conn,
    table_name,
    primary_key,
    row,
    values,
    post_query
  )

  -- TODO: Optimize out table creation
  if not is_table(row) then
    assert(is_number(row) or is_string(row))
    row = { [primary_key] = row }
  end

  post_query = post_query or ''
  arguments(
      "userdata", db_conn,
      "string", table_name,
      "string", primary_key,
      "table",  row,
      "table",  values,
      "string", post_query
    )

  if not row[primary_key] then
    -- NOTE: If you need to do this, you need another function.
    return nil, "add_values_one failed: can't update row without primary key"
  end

  if next(values) == nil then
    return nil, "add_values_one failed: nothing to changes"
  end

  local sets, checks = { }, { }

  -- Extra paranoid checks since we're likely to deal with money here.
  for field, value in pairs(values) do
    if row[field] ~= nil then
      return
        nil,
        "add_values_one failed: ambiguous value for " .. tostring(field)
    end

    if not tonumber(value) then
      return
        nil,
        "add_values_one failed: wrong value type for " .. tostring(field)
    end

    if tonumber(value) < 0 then
      return
        nil,
        "add_values_one failed: negative value for " .. tostring(field)
    end

    sets[#sets + 1] = "`" .. field .. "`="
      .. "`" .. field .. "`+" .. tonumber(value)

    -- TODO: Add an optional configurable limit?
    -- checks[#checks + 1] = "`" .. field .. "`-" .. tonumber(value) .. ">=0"
  end

  for field, value in pairs(row) do
    checks[#checks + 1] = "`" .. field .. "`='" .. db_conn:escape(value) .. "'"
  end

  local num_affected_rows, err = db_conn:execute(
      [[UPDATE `]]..table_name..[[` SET ]]
   .. table.concat(sets, [[,]])
   .. [[ WHERE 1 AND ]]
   .. table.concat(checks, [[ AND ]])
   .. post_query
   .. [[ LIMIT 1]]
    )

  if not num_affected_rows then
    return nil, "add_values_one failed: " .. err
  end

  if num_affected_rows == 0 then
    return false
  end

  if num_affected_rows == 1 then
    return true
  end

  return
    nil,
    "add_values_one failed: unexpected number of affected rows: "
    .. tostring(num_affected_rows)
end

local delete_by_id = function(db_conn, table_name, primary_key, id, post_query)
  post_query = post_query or ''
  arguments(
      "userdata", db_conn,
      "string", table_name,
      "string", primary_key,
      --"number", id,
      "string", post_query
    )
  assert(is_number(id) or is_string(id), "bad id")

  local num_affected_rows, err = db_conn:execute(
      [[DELETE FROM `]]..table_name..[[`]]
   .. [[ WHERE 1 AND `]]..primary_key..[[`=']]..db_conn:escape(id)..[[']]
   .. post_query
   .. [[ LIMIT 1]]
    )

  if not num_affected_rows then
    return nil, "delete_by_id failed: " .. err
  end

  if num_affected_rows == 0 then
    return false
  end

  if num_affected_rows == 1 then
    return true
  end

  return nil,
         "delete_by_id failed: unexpected number of affected rows: "
      .. tostring(num_affected_rows)
end

local delete_many = function(db_conn, table_name, primary_key, limit, post_query)
  post_query = post_query or ''
  arguments(
      "userdata", db_conn,
      "string", table_name,
      "string", primary_key,
      "number", limit,
      "string", post_query
    )

  local num_affected_rows, err = db_conn:execute(
      [[DELETE FROM `]]..table_name..[[`]]
   .. [[ WHERE 1]]
   .. post_query
   .. [[ LIMIT ]]..limit
    )

  if not num_affected_rows then
    return nil, "delete_many failed: " .. err
  end

  if num_affected_rows <= limit then
    return num_affected_rows
  end

  return nil,
         "delete_many failed: unexpected number of affected rows: "
      .. tostring(num_affected_rows)
end

local delete_all = function(db_conn, table_name, primary_key, post_query)
  post_query = post_query or ''
  arguments(
      "userdata", db_conn,
      "string", table_name,
      "string", primary_key,
      "string", post_query
    )

  local num_affected_rows, err = db_conn:execute(
      [[DELETE FROM `]]..table_name..[[`]]
   .. [[ WHERE 1]]
   .. post_query
   -- No limit
    )

  if not num_affected_rows then
    return nil, "delete_all failed: " .. err
  end

  return num_affected_rows
end

local list = function(db_conn, table_name, primary_key, post_query, fields)
  post_query = post_query or ''

  fields = fields or '*' -- TODO: Write tests for this
  if is_table(fields) then
    fields = table.concat(fields, ",") -- Intentionally not escaping, be careful
  end
  assert(fields ~= "", "must have fields")

  arguments(
      "userdata", db_conn,
      "string", table_name,
      "string", primary_key, -- Unused
      "string", post_query,
      "string", fields
    )

  local query = [[SELECT ]] .. fields
   .. [[ FROM `]] .. table_name .. [[`]]
   .. [[ WHERE 1]] .. post_query

  local cursor, err = db_conn:execute(query)
  if not cursor then
    return nil, "list failed: " .. err
  end

  local result = { }
  local row = cursor:fetch({ }, "a")
  while row ~= nil do
    result[#result + 1] = row
    row = cursor:fetch({ }, "a")
  end

  cursor:close()

  return result
end

local count = function(db_conn, table_name, primary_key, post_query)
  post_query = post_query or ''
  arguments(
      "userdata", db_conn,
      "string", table_name,
      "string", primary_key, -- Unused
      "string", post_query
    )

  local query = [[SELECT COUNT(*) FROM `]]..table_name..[[`]]
   .. [[ WHERE 1]]
   .. post_query

  local cursor, err = db_conn:execute(query)
  if not cursor then
    log_error("count failed query:", query)
    log_error("count failed err:", err)

    return nil, "count failed: " .. err
  end

  local count_str = cursor:fetch()

  cursor:close()

  local count = tonumber(count_str)
  if not count then
    return nil, "count failed: unexpected COUNT(*) value: " .. count_str
  end

  return count
end

--------------------------------------------------------------------------------

return
{
  postquery_for_data = postquery_for_data;
  --
  get_by_id = get_by_id;
  get_by_data = get_by_data;
  insert_one = insert_one;
  update_one = update_one;
  update_or_insert_one = update_or_insert_one;
  increment_counter = increment_counter;
  subtract_values_one = subtract_values_one;
  add_values_one = add_values_one;
  delete_by_id = delete_by_id;
  delete_many = delete_many;
  delete_all = delete_all;
  list = list;
  count = count;
}
