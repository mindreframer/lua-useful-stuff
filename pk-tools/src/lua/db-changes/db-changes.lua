--------------------------------------------------------------------------------
-- db-changes.lua: handle DB changesets
-- This file is a part of pk-tools library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------

dofile('tools-lib/init/require-serverside.lua')
dofile('tools-lib/init/init.lua')

--------------------------------------------------------------------------------

local run
      = import 'db-changes/run.lua'
      {
        'run'
      }

local make_loggers
      = import 'pk-core/log.lua'
      {
        'make_loggers'
      }

--------------------------------------------------------------------------------

local log, dbg, spam, log_error = make_loggers("db-changes", "DCH")

--------------------------------------------------------------------------------

run(...)
