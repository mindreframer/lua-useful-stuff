--------------------------------------------------------------------------------
-- schema-validator.lua: db schema validator
-- This file is a part of pk-tools library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
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

local is_table,
      is_string
      = import 'lua-nucleo/type.lua'
      {
        'is_table',
        'is_string'
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
      timap,
      tclone
      = import 'lua-nucleo/table-utils.lua'
      {
        'empty_table',
        'timap',
        'tclone'
      }

local do_nothing
      = import 'lua-nucleo/functional.lua'
      {
        'do_nothing'
      }

local make_loggers
      = import 'pk-core/log.lua'
      {
        'make_loggers'
      }

local walk_tagged_tree
      = import 'pk-core/tagged-tree.lua'
      {
        'walk_tagged_tree'
      }

--------------------------------------------------------------------------------

local log, dbg, spam, log_error = make_loggers("schema-validator", "SVA")

--------------------------------------------------------------------------------

-- Validates mandatory data keys and table references
-- Works on a set of tables
-- TODO: Don't crash, return nil, err.
-- TODO: Add even more validation
-- TODO: Better check enum values
-- TODO: Better check flags values
local validate_db_schema
do
  local is_good_field_name = function(v)
    if not is_string(v) then
      return nil, "field name must be a string"
    end

    if v:find("[^a-zA-Z_%-]") then
      return nil, "invalid characters detected in field name"
    end

    return true
  end

  local registerers
  do
    -- Note that primary_key and primary_ref are considered value fields

    registerers = setmetatable(
        { },
        {
          __index = function(t, tag)
            local v = function(walkers, data)
              assert(
                  walkers.current_table_,
                  "this tag must be inside sql:table"
                )

              if walkers.current_serialized_list_ then

                if
                  walkers.current_serialized_list_.fields[data.name] ~= nil
                then
                  error("duplicate sl field name: " .. data.name)
                end
                walkers.current_serialized_list_.fields[data.name] = true

              elseif tag == "metadata" then

                walkers.current_table_.fields["metadata"] = true

              else

                if walkers.current_table_.fields[data.name] ~= nil then
                  error("duplicate field name: " .. data.name)
                end
                walkers.current_table_.fields[data.name] = true

              end

            end

            t[tag] = v

            return v
          end
        }
      )

    registerers.database = do_nothing

    registerers.table = function(walkers, data)
      assert(
          walkers.current_table_ == false,
          "sql:table can't be nested"
        )

      walkers.current_table_ =
      {
        name = data.name;
        fields = { };
        keys = { };
        primary_key = false;
      }
    end

    registerers.serialized_list = function(walkers, data)
      assert(
          walkers.current_serialized_list_ == false,
          "sql:serialized_list can't be nested"
        )

      walkers.current_serialized_list_ =
      {
        name = data.name;
        fields = { };
        keys = { };
        primary_key = false;
      }
    end

    registerers.list_node = do_nothing -- TODO: ?!

    registerers.key = function(walkers, data)
      assert(
          walkers.current_table_,
          "this tag must be inside sql:table"
        )
      assert(
          not walkers.current_serialized_list_,
          "this tag must NOT be inside sql:serialized_list"
        )
      assert(
          walkers.current_table_.keys[data.name] == nil,
          "duplicate key name"
        )
      walkers.current_table_.keys[data.name] = true
    end

    registerers.unique_key = function(walkers, data)
      assert(
          walkers.current_table_,
          "this tag must be inside sql:table"
        )
      assert(
          not walkers.current_serialized_list_,
          "this tag must NOT be inside sql:serialized_list"
        )
      -- Note only data.name is registered
      -- Specific fields are checked in validators
      assert(
          walkers.current_table_.keys[data.name] == nil,
          "duplicate key name"
        )
      walkers.current_table_.keys[data.name] = true
    end

    registerers.primary_key = function(walkers, data)
      assert(
          walkers.current_table_,
          "this tag must be inside sql:table"
        )

      -- TODO: ?! What about serialized_primary_key?!
      if walkers.current_serialized_list_ then

        assert(
            walkers.current_serialized_list_.primary_key == false,
            "duplicate primary key"
          )
        assert(
            walkers.current_serialized_list_.fields[data.name] == nil,
            "duplicate field name"
          )

        walkers.current_serialized_list_.primary_key = data.name
        walkers.current_serialized_list_.fields[data.name] = true

      else

        assert(
            walkers.current_table_.primary_key == false,
            "duplicate primary key"
          )
        assert(
            walkers.current_table_.fields[data.name] == nil,
            "duplicate field name"
          )

        walkers.current_table_.primary_key = data.name
        walkers.current_table_.fields[data.name] = true

      end

    end

    registerers.primary_ref = function(walkers, data)
      assert(
          walkers.current_table_,
          "this tag must be inside sql:table"
        )

      if walkers.current_serialized_list_ then

        -- TODO: ?! What about serialized_primary_ref?!
        assert(
            walkers.current_serialized_list_.primary_key == false,
            "duplicate primary key"
          )
        assert(
            walkers.current_serialized_list_.fields[data.name] == nil,
            "duplicate field name"
          )

        walkers.current_serialized_list_.primary_key = data.name
        walkers.current_serialized_list_.fields[data.name] = true

      else

        assert(
            walkers.current_table_.primary_key == false,
            "duplicate primary key"
          )
        assert(
            walkers.current_table_.fields[data.name] == nil,
            "duplicate field name"
          )

        walkers.current_table_.primary_key = data.name
        walkers.current_table_.fields[data.name] = true

      end

    end
  end

  local validators
  do
    local check_field_name = function(walkers, data)
      assert(is_good_field_name(data.name))
    end

    local check_ref = function(walkers, data)
      -- TODO: Validate that primary key type matches reference field type.
      check_field_name(walkers, data)
      assert(walkers.known_tables_[data.table], "unknown reference table")
    end

    validators = setmetatable(
        { },
        {
          __index = function(t, k)
            error("unknown method `" .. tostring(k) .. "'", 2)
          end
        }
      )

    validators.list_node = do_nothing
    validators.serialized_primary_key = check_field_name
    validators.serialized_primary_ref = check_ref

    validators.database = do_nothing
    validators.metadata = do_nothing -- TODO: Fix
    validators.boolean = check_field_name
    validators.counter = check_field_name
    validators.int = check_field_name
    validators.ip = check_field_name
    validators.md5 = check_field_name
    validators.password = check_field_name
    validators.optional_ip = check_field_name
    validators.optional_ref = check_ref
    validators.ref = check_ref
    validators.serialized_list = check_field_name
    validators.text = check_field_name
    validators.timeofday = check_field_name
    validators.timestamp = check_field_name
    validators.day_timestamp = check_field_name
    validators.timestamp_created = check_field_name
    validators.uuid = check_field_name
    validators.weekdays = check_field_name
    validators.primary_key = check_field_name
    validators.primary_ref = check_ref

    validators.string = function(walkers, data)
      check_field_name(walkers, data)
      local size = assert_is_number(data[1], "missing string size")
      assert(size > 0 and size <= 256, "bad string size")
      assert(size % 1 == 0, "non-integer string size")
    end

    validators.int_enum = function(walkers, data)
      check_field_name(walkers, data)
      assert_is_table(data[1], "missing enum values")
      assert(next(data[1]) ~= nil, "enum must be non-empty")
      -- TODO: Check more
    end

    validators.flags = function(walkers, data)
      check_field_name(walkers, data)
      assert_is_table(data[1], "missing flags values") -- TODO: Check more
    end

    validators.table = function(walkers, data)
      check_field_name(walkers, data)
      assert(data.singular_name, "singular_name missing")
      assert(data.db_name, "db_name missing")
      walkers.current_table_ = false
    end

    validators.serialized_list = function(walkers, data)
      check_field_name(walkers, data)
      --assert(data.singular_name, "singular_name missing")
      --assert(data.db_name, "db_name missing")
      walkers.current_serialized_list_ = false
    end

    validators.key = function(walkers, data)
      check_field_name(walkers, data)

      if #data == 0 then
        if not walkers.current_table_.fields[data.name] then
          log_error(
              "unknown key field name: ",
              data.name,
              walkers.current_table_.fields
            )
          error("unknown key field name `" .. data.name .. "'")
        end
      elseif #data == 1 then
        assert(
            data.name ~= walkers.current_table_.primary_key,
            "key name duplicates primary key"
          )
      else
        assert(
            not walkers.current_table_.fields[data.name],
            "multicolumn key field name can't match existing field"
          )
        for i = 1, #data do
          assert_is_string(data[i], "bad key field")
          if not walkers.current_table_.fields[data[i]] then
            error(
                "unknown key field name `" .. data[i] .. "'"
              )
          end
        end
      end
    end

    validators.unique_key = function(walkers, data)
      check_field_name(walkers, data)
      assert(
          data.name ~= walkers.current_table_.primary_key,
          "key name duplicates primary key"
        )

      if #data == 0 then
        log_error("missing unique key fields: ", data)
        error("missing unique key fields")
      end

      if #data == 1 then
        assert(
            data[1] ~= walkers.current_table_.primary_key,
            "unique key field duplicates primary key"
          )
      end

      for i = 1, #data do
        assert_is_string(data[i], "bad unique key field")
        assert(
            walkers.current_table_.fields[data[i]],
            "unknown unique key field name"
          )
      end
    end
  end

  validate_db_schema = function(tables, known_tables)
    known_tables = known_tables or empty_table
    arguments(
        "table", tables,
        "table", known_tables
      )

    -- Add our tables to the list of known tables
    known_tables = tclone(known_tables)
    for i = 1, #tables do
      assert(
          known_tables[assert_is_string(tables[i].name)] == nil,
          "duplicate table name"
        )
      known_tables[tables[i].name] = true
    end

    local walkers =
    {
      down = registerers;
      up = validators;
      --
      known_tables_ = known_tables;
      current_table_ = false;
      current_serialized_list_ = false;
    }

    -- Walk all tables and validate them one-by-one
    for i = 1, #tables do
      log("validating", i, tables[i].name)
      walk_tagged_tree(tables[i], walkers, "tag")
    end

    log("all tables validated OK")
  end
end

-- TODO: Use checker to report all errors at once!

--------------------------------------------------------------------------------

return
{
  validate_db_schema = validate_db_schema;
}
