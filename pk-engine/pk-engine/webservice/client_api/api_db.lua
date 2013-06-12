--------------------------------------------------------------------------------
-- api_db.lua: db wrapper for api
-- This file is a part of pk-engine library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------
--
-- WARNING: To be used inside call().
--
-- TODO: Prevent calling make_api_db_mt() and make_db_tables_mt() each time
--       when creating api_db
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

local is_table
      = import 'lua-nucleo/type.lua'
      {
        'is_table'
      }

local assert_is_table
      = import 'lua-nucleo/typeassert.lua'
      {
        'assert_is_table'
      }

local unique_object
      = import 'lua-nucleo/misc.lua'
      {
        'unique_object'
      }

local make_loggers
      = import 'pk-core/log.lua'
      {
        'make_loggers'
      }

local postquery_for_data
      = import 'pk-engine/db/query.lua'
      {
        'postquery_for_data'
      }

local make_enquirer
      = import 'pk-engine/db/enquirer.lua'
      {
        'make_enquirer'
      }

local try
      = import 'pk-core/error.lua'
      {
        'try'
      }

--------------------------------------------------------------------------------

local log, dbg, spam, log_error = make_loggers("webservice/client_api/api_db", "ADB")

--------------------------------------------------------------------------------

local make_api_db_table
do
  local common_enquirer_delegate = function(method_name)
    return function(self, ...)
      method_arguments(self)

      local enquirer = self.enquirer_

      return enquirer[method_name](enquirer, self.db_conn_, ...)
    end
  end

  -- A special case.
  local get = function(self, what, postquery)
    method_arguments(self)
    -- Rest of arguments have variable types

    if is_table(what) then
      return self.enquirer_:get_by_data(self.db_conn_, what, postquery)
    end

    return self.enquirer_:get_by_id(self.db_conn_, what, postquery)
  end

  -- A special case.
  local delete = function(self, what, postquery)
    method_arguments(self)
    -- Rest of arguments have variable types

    if is_table(what) then
      local num_affected_rows, err = self.enquirer_:delete_many(
          self.db_conn_,
          1,
          postquery_for_data(self.db_conn_, what) .. (postquery or "")
        )

      -- Imitate delete_one() return value contract.
      if num_affected_rows == 1 then
        return true -- Found and deleted
      elseif num_affected_rows == 0 then
        return false -- Not found
      elseif num_affected_rows == nil then
        log_error("delete_many failed:", err)
        return nil, err -- Propagate error
      else
        return nil,
               "delete failed: unexpected number of affected rows: "
            .. tostring(num_affected_rows)
      end
    end

    return self.enquirer_:delete_by_id(self.db_conn_, what, postquery)
  end

  -- A special case.
  local delete_all = function(self, what, postquery)
    method_arguments(self)
    -- Rest of arguments have variable types

    postquery = postquery or ""

    if what then
      assert_is_table(what)
      postquery = postquery .. postquery_for_data(self.db_conn_, what)
    end

    return self.enquirer_:delete_all(
        self.db_conn_,
        postquery
      )
  end

  -- A special case.
  local count = function(self, what, postquery)
    method_arguments(self)
    -- Rest of arguments have variable types

    if is_table(what) then
      return self.enquirer_:count(
          self.db_conn_,
          postquery_for_data(self.db_conn_, what) .. (postquery or "")
        )
    end

    return self.enquirer_:count(self.db_conn_, what, postquery)
  end

  -- A special case.
  local list = function(self, what, postquery, fields)
    method_arguments(self)
    -- Rest of arguments have variable types

    if is_table(what) then
      return self.enquirer_:list(
          self.db_conn_,
          postquery_for_data(self.db_conn_, what) .. (postquery or ""),
          fields
        )
    end

    return self.enquirer_:list(self.db_conn_, what .. (postquery or ""), fields)
  end

  -- A custom method
  -- WARNING: Call right after insert() only!
  local getlastautoid = function(self)
    method_arguments(self)
    return self.db_conn_:getlastautoid()
  end

  -- TODO: That should be a method of api_db, not api_db_table
  local escape = function(self, str)
    method_arguments(
        self,
        "string", str
      )
    return self.db_conn_:escape(str)
  end

  local insert = common_enquirer_delegate("insert_one")
  local update = common_enquirer_delegate("update_one")
  local update_or_insert = common_enquirer_delegate("update_or_insert_one")
  local increment_counter = common_enquirer_delegate("increment_counter")
  local subtract_values = common_enquirer_delegate("subtract_values_one")
  local add_values = common_enquirer_delegate("add_values_one")

  -- TODO: This should support table arguments
  local delete_many = common_enquirer_delegate("delete_many")

  make_api_db_table = function(enquirer, db_conn)
    arguments(
        "table", enquirer,
        "userdata", db_conn
      )

    return
    {
      get = get;
      insert = insert;
      update = update;
      update_or_insert = update_or_insert;
      increment_counter = increment_counter;
      subtract_values = subtract_values;
      add_values = add_values;
      delete = delete;
      delete_many = delete_many;
      delete_all = delete_all;
      list = list;
      count = count;
      --
      getlastautoid = getlastautoid;
      escape = escape;
      --
      enquirer_ = enquirer;
      db_conn_ = db_conn;
    }
  end
end

--------------------------------------------------------------------------------

local make_api_db, destroy_api_db
do
  local db_manager_key = unique_object()
  local connections_cache_key = unique_object()
  local factories_cache_key = unique_object()
  local db_tables_key = unique_object()

  local connections_mt =
  {
    __index = function(t, db_name)
      local db_conn, conn_id = try(
          "INTERNAL_ERROR",
          t[db_manager_key]:acquire_db_connection(db_name)
        )

      local v = { db_conn = db_conn, conn_id = conn_id }
      t[db_name] = v
      return v
    end
  }

  local factories_mt =
  {
    __index = function(t, table_name)
      local v = function(self) -- TODO: Weird.
        return self[db_tables_key][table_name]
      end
      t[table_name] = v
      return v
    end;
  }

  local make_db_tables_mt = function(db_tables)
    arguments(
      "table", db_tables
      )
    return
    {
      __index = function(t, table_name)
        local table = db_tables[table_name]
        local v = make_api_db_table(
            make_enquirer(table.table, table.primary_key, table.features),
            t[connections_cache_key][table.db_name].db_conn
          )
        t[table_name] = v
        return v
      end;
    }
  end

  -- TODO: Support identically named tables in different databases?
  local make_api_db_mt = function(db_tables)
    arguments(
      "table", db_tables
      )
    return
    {
      __index = function(self, table_name)
        method_arguments(
            self,
            "string", table_name
          )

        if not db_tables[table_name] then
          error("unknown table " .. table_name, 2)
        end

        local v = self[factories_cache_key][table_name]
        self[table_name] = v
        return v
      end;
    }
  end

  -- A out-of-class method to allow tables named "destroy"
  destroy_api_db = function(self)
    method_arguments(self)

    local connections = self[db_tables_key][connections_cache_key]
    local db_manager = connections[db_manager_key]

    for db_name, info in pairs(connections) do
      if db_name ~= db_manager_key then -- Hack
        db_manager:unacquire_db_connection(info.db_conn, info.conn_id)
        connections[db_name] = nil
      end
    end
  end

  make_api_db = function(db_tables, db_manager)
    arguments(
        "table", db_tables,
        "table", db_manager
      )

    return setmetatable(
        {
          [factories_cache_key] = setmetatable({ }, factories_mt);
          [db_tables_key] = setmetatable(
              {
                [connections_cache_key] = setmetatable(
                    {
                      [db_manager_key] = db_manager;
                    },
                    connections_mt
                  );
              },
              make_db_tables_mt(db_tables)
            );
        },
        make_api_db_mt(db_tables)
      )
  end
end

--------------------------------------------------------------------------------

return
{
  destroy_api_db = destroy_api_db;
  make_api_db = make_api_db;
}
