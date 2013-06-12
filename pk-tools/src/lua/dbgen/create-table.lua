--------------------------------------------------------------------------------
-- create-table.lua: CREATE TABLE SQL query generators
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

local is_table
      = import 'lua-nucleo/type.lua'
      {
        'is_table'
      }

local assert_is_table,
      assert_is_number
      = import 'lua-nucleo/typeassert.lua'
      {
        'assert_is_table',
        'assert_is_number'
      }

local empty_table,
      timap
      = import 'lua-nucleo/table-utils.lua'
      {
        'empty_table',
        'timap'
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

local walk_tagged_tree,
      create_simple_tagged_tree_walkers
      = import 'pk-core/tagged-tree.lua'
      {
        'walk_tagged_tree',
        'create_simple_tagged_tree_walkers'
      }

--------------------------------------------------------------------------------

local log, dbg, spam, log_error = make_loggers("create-table", "CTA")

--------------------------------------------------------------------------------

local F = function(name)
  return '`' .. name .. '`'
end

local make_create_table_builder
do
  local commit = function(self)
    method_arguments(self)
    assert(self.name_ ~= nil, "attempted to commit with no name")
    assert(next(self.fields_) ~= nil, "attempted to commit with no fields")
    -- No keys is ok

    local body = table.concat(self.fields_, ",\n  ")
    if next(self.keys_) ~= nil then
      body = body .. ",\n  " .. table.concat(self.keys_, ",\n  ")
    end

    -- TODO: Make engine and charset configurable.
    return [[
CREATE TABLE ]] .. (F(self.name_)) .. [[ (
  ]] .. (body) .. [[

) ENGINE=MyISAM DEFAULT CHARSET=utf8
]]
  end

  local reset = function(self)
    method_arguments(self)
    self.name_ = nil
    self.keys_ = { }
    self.fields_ = { }
  end

  local set_name = function(self, name)
    method_arguments(
        self,
        "string", name
      )
    assert(self.name_ == nil, "name is already set")

    self.name_ = name
  end

  local add_key = function(self, key)
    method_arguments(
        self,
        "string", key
      )

    self.keys_[#self.keys_ + 1] = key
  end

  local add_field = function(self, field)
    method_arguments(
        self,
        "string", field
      )

    self.fields_[#self.fields_ + 1] = field
  end

  make_create_table_builder = function()

    return
    {
      commit = commit;
      reset = reset;
      --
      set_name = set_name;
      add_key = add_key;
      add_field = add_field;
      --
      name_ = nil;
      keys_ = { };
      fields_ = { };
    }
  end
end

local make_create_table_renderer
do
  local renderers = { }
  do
    local int = function(size)
      return function(self, data)
        size = size or assert_is_number(data[1], "bad size")
        self:add_field(
            (F(data.name)) .. [[ int(]] .. size .. [[) NOT NULL default '0']]
          )
      end
    end

    local varchar = function(size)
      return function(self, data)
        size = size or assert_is_number(data[1], "bad size")
        self:add_field(
            (F(data.name)) .. [[ varchar(]] .. size .. [[) NOT NULL default '']]
          )
      end
    end

    local text = function(self, data)
      self:add_field(
          (F(data.name)) .. [[ text NOT NULL]]
        )
    end

    local blob = function(self, data)
      self:add_field(
          (F(data.name)) .. [[ blob NOT NULL]]
        )
    end

    renderers.database = do_nothing
    renderers.metadata = do_nothing

    renderers.blob = blob
    renderers.boolean = int(4)
    renderers.counter = int(11)
    renderers.flags = int(11)
    renderers.int = int(11)
    renderers.int_enum = int(11) -- TODO: Use enum SQL type?
    renderers.ip = varchar(15)
    renderers.list_node = do_nothing -- TODO: ?!
    renderers.md5 = varchar(32)
    renderers.password = varchar(32)
    renderers.optional_ip = varchar(15)
    renderers.optional_ref = int(11)
    renderers.ref = int(11)
    renderers.serialized_list = blob
    renderers.serialized_primary_key = do_nothing -- TODO: ?!
    renderers.serialized_primary_ref = do_nothing -- TODO: ?!
    renderers.string = varchar(nil)
    renderers.text = text
    renderers.timeofday = int(11) -- TODO: Reduce data size
    renderers.day_timestamp = int(11)
    renderers.timestamp = int(11)
    renderers.timestamp_created = int(11)
    renderers.uuid = varchar(37)
    renderers.weekdays = int(11) -- TODO: Reduce data size

    renderers.table = function(self, data)
      self:set_name(data.name)
    end

    renderers.key = function(self, data)
      if #data == 0 then
        self:add_key(
            [[ KEY ]] .. (F(data.name)) .. [[ (]] .. (F(data.name)) .. [[)]]
          )
      else
        self:add_key(
            [[ KEY ]] .. (F(data.name))
         .. [[ (]]
         .. table.concat(timap(F, data), [[, ]])
         .. [[)]]
          )
      end
    end

    renderers.primary_key = function(self, data)
      -- TODO: Allow custom key types
      -- TODO: Allow disabled autoincrement

      self:add_field(
          (F(data.name)) .. [[ int(11) NOT NULL auto_increment]]
        )

      self:add_key(
          [[ PRIMARY KEY ]] .. [[ (]] .. (F(data.name)) .. [[)]]
        )
    end

    renderers.primary_ref = function(self, data)
      self:add_field(
          (F(data.name)) .. [[ int(11) NOT NULL default 0]]
        )

      self:add_key(
          [[ PRIMARY KEY ]] .. [[ (]] .. (F(data.name)) .. [[)]]
        )
    end


    renderers.unique_key = function(self, data)
      self:add_key(
          [[ UNIQUE KEY ]] .. (F(data.name))
       .. [[ (]]
       .. table.concat(timap(F, data), [[, ]])
       .. [[)]]
        )
    end
  end

  local render = function(self, data)
    method_arguments(
        self,
        "table", data
      )

    self.builder_:reset()
    walk_tagged_tree(data, self.walkers_, "tag")
    return self.builder_:commit()
  end

  make_create_table_renderer = function()
    local builder = make_create_table_builder()

    return
    {
      render = render;
      --
      builder_ = builder;
      walkers_ = create_simple_tagged_tree_walkers(builder, renderers);
    }
  end
end

--------------------------------------------------------------------------------

return
{
  make_create_table_renderer = make_create_table_renderer;
}
