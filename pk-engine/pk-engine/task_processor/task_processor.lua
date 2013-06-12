--------------------------------------------------------------------------------
-- task_processor.lua: entity which can run tasks
-- This file is a part of pk-engine library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------

local luabins = require 'luabins'

--------------------------------------------------------------------------------

local debug_traceback = debug.traceback

--------------------------------------------------------------------------------

local arguments,
      method_arguments
      = import 'lua-nucleo/args.lua'
      {
        'arguments',
        'method_arguments'
      }

local assert_is_table,
      assert_is_function,
      assert_is_string,
      assert_is_number
      = import 'lua-nucleo/typeassert.lua'
      {
        'assert_is_table',
        'assert_is_function',
        'assert_is_string',
        'assert_is_number'
      }

local is_string,
      is_table,
      is_function
      = import 'lua-nucleo/type.lua'
      {
        'is_string',
        'is_table',
        'is_function'
      }

local try_unwrap
      = import 'pk-engine/hiredis/util.lua'
      {
        'try_unwrap'
      }

local make_loggers
      = import 'pk-core/log.lua'
      {
        'make_loggers'
      }

--------------------------------------------------------------------------------

local log, dbg, spam, log_error = make_loggers("task_processor", "TSP")

--------------------------------------------------------------------------------

local args_save = luabins.save
local args_load = luabins.load

--------------------------------------------------------------------------------

local try_init_db = function(api_context, db_name)
  arguments(
      "table", api_context,
      "string", db_name
    )

  local redis = api_context:hiredis()
  local db = redis[db_name](redis)

  --TODO: remove external PING: https://redmine.iphonestudio.ru/issues/1782
  try_unwrap(
      "INTERNAL_ERROR",
      db:command("PING")
    )
  return db
end

--------------------------------------------------------------------------------

local try_validate_config = function(config)

  local task_processor = config.task_processor
  assert_is_table(task_processor, "no task_processor params in config")
  assert_is_string(task_processor.db_name, "bad db name in task_processor config")
  assert_is_string(task_processor.key, "bad key value in task_processor config")

  return task_processor
end

--------------------------------------------------------------------------------

local make_task_processor
do
  local step
  do
    local err_handler = function(msg)
      msg = debug_traceback("task run error:\n" .. msg, 2)
      return msg
    end

    local run_task = function(self, task_name, ...)
      method_arguments(
          self,
          "string", task_name
        )

      local task = self.tasks_[task_name]
      if task == nil then
        log_error("can't find task:", task_name)
        return nil, "can't find task: " .. task_name
      end

      if not is_table(task) then
        log_error("task", task_name, "has bad exports")
        return nil, "task: " .. task_name .. " has bad exports"
      end

      if not is_function(task.run) then
        log_error("task", task_name, "lacks run function")
        return nil, "task: " .. task_name .. " lacks run function"
      end

      log("runing task:", task_name, ", with params:", ...)
      local success, res, err = xpcall(
          function(...)
            return task.run(self.api_context_, ...)
          end,
          err_handler,
          ...
        )

      if not success then
        log_error("run_task: failed:\n", res)
        return nil, res
      elseif res ~= true then
        if err == nil then
          err = "unknown error (missed 'return true'?)"
        end
        log_error("run_task: bad call:\n", err)
        return nil, err
      end

      return true
    end

    local check_args = function(res, ...)
      if res ~= true then
        return nil, ...
      end
      return { ... }
    end

    step = function(self, timeout)

      method_arguments(self, "number", timeout)

      local data = try_unwrap(
          "INTERNAL_ERROR",
          self.db_:command("BLPOP", self.key_, timeout)
        )

      if data == hiredis.NIL then
        return nil, "Task queue is empty"
      end

      if not is_table(data) then
        log_error("Wrong redis response: data is not a table:", data)
        return nil, "wrong redis response"
      end

      local saved_call = data[2]

      local args, err = check_args(luabins.load(saved_call))

      if args == nil then
        log_error("load_args failed:", err)
        return nil, err
      end

      local res, err = run_task(self, unpack(args))

      if not res then
        log_error("run_task failed:", err)
        return nil, err
      end

      return true
    end
  end

  make_task_processor = function(api_context, config, tasks)
    arguments(
        "table", api_context,
        "table", config,
        "table", tasks
      )

    config = try_validate_config(config)

    local db = try_init_db(api_context, config.db_name)

    return
    {
      step = step;
      --
      api_context_ = api_context;

      tasks_ = tasks;
      db_ = db;
      key_ = config.key;
    }
  end
end

local add_task = function(api_context, config, args)
  arguments(
      "table", api_context,
      "table", config,
      "string", args
    )

  config = try_validate_config(config)

  local db = try_init_db(api_context, config.db_name)

  try_unwrap(
      "INTERNAL_ERROR",
      db:command("RPUSH", config.key, args)
    )

end

--------------------------------------------------------------------------------

return
{
  args_save = args_save;
  args_load = args_load;
  make_task_processor = make_task_processor;
  add_task = add_task;
}
