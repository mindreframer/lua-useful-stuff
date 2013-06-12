--------------------------------------------------------------------------------
-- update_changes.lua: update changesets for DB schema
-- This file is a part of pk-tools library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------

local uuid = require 'uuid'

--------------------------------------------------------------------------------

local arguments,
      optional_arguments,
      method_arguments,
      eat_true
      = import 'lua-nucleo/args.lua'
      {
        'arguments',
        'optional_arguments',
        'method_arguments',
        'eat_true'
      }

local is_table
      = import 'lua-nucleo/type.lua'
      {
        'is_table'
      }

local assert_is_table,
      assert_is_number,
      assert_is_string
      = import 'lua-nucleo/typeassert.lua'
      {
        'assert_is_table',
        'assert_is_number',
        'assert_is_string'
      }

local empty_table,
      timap
      = import 'lua-nucleo/table.lua'
      {
        'empty_table',
        'timap'
      }

local escape_lua_pattern
      = import 'lua-nucleo/string.lua'
      {
        'escape_lua_pattern'
      }

local find_all_files
      = import 'lua-aplicado/filesystem.lua'
      {
        'find_all_files'
      }

local make_loggers
      = import 'pk-core/log.lua'
      {
        'make_loggers'
      }

local make_create_table_renderer
      = import 'dbgen/create-table.lua'
      {
        'make_create_table_renderer'
      }

local format_changeset
      = import 'dbgen/changeset.lua'
      {
        'format_changeset'
      }

--------------------------------------------------------------------------------

local log, dbg, spam, log_error = make_loggers("update-changes", "UPC")

--------------------------------------------------------------------------------

local generate_create_changeset = function(data, create_table_renderer)
  local create_table = create_table_renderer:render(data)

  -- Need to pad it to match indentation
  create_table = create_table:gsub("\n(.)", "\n    %1")

  return
  {
    table_name = assert_is_string(data.name);
    data =
    {
      DB_NAME = assert_is_string(data.db_name);
      UUID = data.db_name .. "/" .. data.name .. "/create/" .. uuid.new();

      apply = [=[
function(db_conn)
  return db_conn:execute [[
    ]=] .. create_table .. [=[
  ]]
end
]=];

      revert = [=[
function(db_conn)
  return db_conn:execute [[DROP TABLE `]=] .. data.name .. [=[`]]
end
]=];
    };
  }
end

local convert_db_schema_to_changesets = function(tables)
  local create_table_renderer = make_create_table_renderer()

  return timap(generate_create_changeset, tables, create_table_renderer)
end

--------------------------------------------------------------------------------

local update_changesets = function(
    new_changesets,
    out_dir,
    force,
    suffix,
    ignore_in_tests
  )
  log(
      "updating", suffix,
      "changesets in", out_dir .. "/",
      ignore_in_tests and "ignored in tests" or "included in tests",
      force and "(forced)" or ""
    )

  local existing_changesets = find_all_files(out_dir, "^.*%.lua$")
  table.sort(existing_changesets)

  -- Find largest used ID (and check changeset structure)
  local last_n = 0
  local create_changesets = { }
  for i = 1, #existing_changesets do
    local changeset_name = existing_changesets[i]

    local n_str, name = changeset_name:match(
        "^" .. escape_lua_pattern(out_dir) .. "/(%d%d%d%d)%-(.*)%.lua$"
      )
    local n = tonumber(n_str)
    if not n or not name then
      error("invalid changeset file name: `" .. changeset_name .. "'")
    end

    if n > last_n then
      last_n = n
    end

    local table_name = name:match("(.-)%-".. suffix .. "$")
    if table_name then
      log(
          "found existing", suffix, table_name,
          "changeset", changeset_name
        )
      assert(
          create_changesets[table_name] == nil,
          "found duplicate " .. suffix .. " changeset"
        )
      create_changesets[table_name] = changeset_name
    end
  end

  local num_skipped = 0
  for i = 1, #new_changesets do
    local changeset = new_changesets[i]

    changeset.ignore_in_tests = ignore_in_tests -- TODO: ?!

    local table_name = changeset.table_name

    local changeset_str = false
    local filename = false
    local skip = false

    -- Check if changeset already exists
    local existing_changeset = create_changesets[table_name]
    if existing_changeset then
      log("loading old changeset from", existing_changeset)

      local data_str
      do
        local file = assert(io.open(existing_changeset, "r"))
        data_str = file:read("*a")
        file:close()
      end

      local data = assert_is_table(
          assert(loadstring(data_str, "@"..existing_changeset))(),
          "broken changeset"
        )

      -- Patch our changeset uuid
      local old_uuid = changeset.data.UUID
      changeset.data.UUID = data.UUID
      changeset_str = format_changeset(changeset.data)

      skip = (data_str == changeset_str)
      if skip then
        log("table", table_name, "not changed, skipping")
      elseif not force then
        error("refusing to override existing changeset " .. existing_changeset)
      else
        -- Restoring uuid -- want user to know changeset is different! (?!)
        --changeset.data.UUID = old_uuid
        -- TODO: Do not re-generate changeset?
        changeset_str = format_changeset(changeset.data)

        log(
            "overriding existing changeset",
            existing_changeset,
            "for table", table_name
          )
        filename = existing_changeset
      end
    end

    if skip then
      num_skipped = num_skipped + 1
    else
      if not filename then
        last_n = last_n + 1
        -- TODO: Remove four digit limit on changeset number
        assert(last_n < 10000, "too many changesets")
        filename = ("%s/%04d-%s-%s.lua"):format(
            out_dir,
            last_n,
            table_name,
            suffix
          )
      end

      log("writing changeset for table", table_name, "to", filename)

      local file = assert(io.open(filename, "w"))
      file:write(changeset_str or format_changeset(changeset.data))
      file:close()
      file = nil
    end
  end

  log("OK")
  log("total:", #new_changesets, "changesets")
  log("updated:", #new_changesets - num_skipped, "changesets")
  log("unchanged:", num_skipped, "changesets")
end

--------------------------------------------------------------------------------

return
{
  convert_db_schema_to_changesets = convert_db_schema_to_changesets;
  update_changesets = update_changesets;
}
