--------------------------------------------------------------------------------
-- db-tables-test-data.lua: generate tables-test-data.lua
-- This file is a part of pk-tools library
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
        'method_arguments',
      }

local make_concatter
      = import 'lua-nucleo/string.lua'
      {
        'make_concatter'
      }

local tset,
      tstr
      = import 'lua-nucleo/table.lua'
      {
        'tset',
        'tstr'
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

local make_data_faker
      = import 'pk-engine/data_faker.lua'
      {
        'make_data_faker'
      }

--------------------------------------------------------------------------------

local log, dbg, spam, log_error = make_loggers("db-tables-test-data", "DTD")

--------------------------------------------------------------------------------

-- TODO: Assuming all fields faker may return are convertible to string.
--       Convert to string explicitly.
local generate_db_tables_test_data
do
  local tag_aliases =
  {
    serialized_primary_key = "primary_key";
    serialized_primary_ref = "primary_ref";
  }

  local ignored_tags = tset { "database", "metadata", "key", "unique_key" }
  local bad_patch_tags = tset { "primary_key", "primary_ref" }
  local argument_tags = tset { "string", "int_enum", "flags" }

  local Q = function(v)
    local t = type(v)
    if t == "number" then
      return v
    elseif t == "table" then
      return "luabins.save(" .. tstr(v) .. ")"
    end
    return ("%q"):format(tostring(v))
  end

  -- TODO: Generalize
  local indent_cache = setmetatable(
      { },
      {
        __index = function(t, k)
          local v = ("  "):rep(k)
          t[k] = v
          return v
        end;
      }
    )

  -- TODO: Refactor this
  local cat_fake_data = function(walkers, data)
    local tag = data.tag

    tag = tag_aliases[tag] or tag

    -- Compound tags should be handled elsewhere
    assert(tag ~= "serialized_list" and tag ~= "list_node")
    assert(tag ~= "metadata")

    local handler = walkers.faker_[tag]
    if not handler then
      error("don't know how to generate fake data for " .. tag, 2)
    end

    local value
    if argument_tags[tag] then
      value = handler(walkers.faker_, data[1])
    else
      value = handler(walkers.faker_)
    end

    local patch_field_value = walkers.patch_field_value_

    if data == walkers.patch_field_ then
      if patch_field_value == nil then -- Serializing field itself
        walkers.patch_field_value_ = value
      else -- Serializing patch field value
        local count = 0
        while value == patch_field_value do
          log("regenerating patch value for", tag, "field", data.name)

          if argument_tags[tag] then
            value = handler(walkers.faker_, data[1])
          else
            value = handler(walkers.faker_)
          end

          count = count + 1
          assert(count <= 10, "can't generate patch value")
        end
      end
    end

    walkers.cat_ [[
    ]] (indent_cache[walkers.nesting_]) [[]] (data.name) [[ = ]] (Q(value)) [[;
]]

    return walkers.cat_
  end

  local cat_simple_row_patch = function(walkers, data)
    local cat = walkers.cat_

    if walkers.patch_field_ then
      walkers.cat_ [[
  simple_row_patch =
  {
]] cat_fake_data(walkers, walkers.patch_field_) [[
  };
]]
    end

    return cat
  end

  local down = { }

  down.serialized_list = function(walkers, data)
    -- HACK.
    walkers.cat_ [[
    ]] (data.name) [[ = luabins.save
    {
]]
    walkers.nesting_ = walkers.nesting_ + 1
  end

  down.list_node = function(walkers, data)
    -- HACK: not catting data.name
    walkers.cat_ [[
      {
]]
    walkers.nesting_ = walkers.nesting_ + 1
  end

  down.table = function(walkers, data)
    walkers.patch_field_ = false
    walkers.patch_field_value_ = nil
    -- TODO: Check in validation stage that data.name is a valid Lua identifier!
    walkers.cat_ [[
TEST_DATA.]] (data.name) [[ =
{
  simple_row =
  {
]]
  end

  local field_up = function(tag)
    return function(walkers, data)
      if not bad_patch_tags[tag] and not walkers.patch_field_ then
        walkers.patch_field_ = data
      end

      cat_fake_data(walkers, data)
    end
  end

  local up = setmetatable(
      { },
      {
        __index = function(t, tag)
          local v = nil
          if not ignored_tags[tag] then
            v = field_up(tag)
            t[tag] = v
          end
          return v
        end;
      }
    )

  up.table = function(walkers, data)
    -- TODO: Support custom features table.
    walkers.cat_ [[
  };
]] cat_simple_row_patch(walkers, data) [[
}

]]
  end

  up.serialized_list = function(walkers, data)
    walkers.nesting_ = walkers.nesting_ - 1
    walkers.cat_ [[
    };
]]
  end

  up.list_node = function(walkers, data)
    walkers.nesting_ = walkers.nesting_ - 1
    walkers.cat_ [[
      };
]]
  end

  generate_db_tables_test_data = function(tables)
    local cat, concat = make_concatter()

    local walkers =
    {
      down = down;
      up = up;
      --
      cat_ = cat;
      faker_ = make_data_faker();
      patch_field_ = false;
      patch_value_ = nil;
      nesting_ = 0;
    }

    for i = 1, #tables do
      walk_tagged_tree(tables[i], walkers, "tag")
    end

    return [[
--------------------------------------------------------------------------------
-- tables-test-data.lua: generated table 'contract' information for tests
--------------------------------------------------------------------------------
-- WARNING! Do not change manually.
-- Generated by db-tables-test-data.lua
--------------------------------------------------------------------------------

local luabins = require 'luabins'

--------------------------------------------------------------------------------

local tserialize
      = import 'lua-nucleo/tserialize.lua'
      {
        'tserialize'
      }

--------------------------------------------------------------------------------

local TEST_DATA = { }

--------------------------------------------------------------------------------

]] .. concat() .. [[
--------------------------------------------------------------------------------

return TEST_DATA
]]
  end
end

--------------------------------------------------------------------------------

return
{
  generate_db_tables_test_data = generate_db_tables_test_data;
}
