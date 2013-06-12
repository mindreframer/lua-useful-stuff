--------------------------------------------------------------------------------
-- module.lua: module bootstrapper
-- This file is a part of pk-engine library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------

require 'lua-nucleo.module'
require 'lua-aplicado.module'

-- You may also want to require 'lua-nucleo.strict'.

-- TODO: Verify this list!
require 'copas' -- Should be loaded first
require 'posix'
require 'socket'
require 'socket.http'
require 'luabins'
require 'socket.url'
require 'md5'
require 'luasql.mysql'
require 'uuid'
require 'lfs'
require 'ev'
require 'ltn12'
require 'random'
