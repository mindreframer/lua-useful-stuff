--------------------------------------------------------------------------------
-- metamanifest.lua: default values used by generator
-- This file is a part of pk-project-tools library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------

local escape_lua_pattern =
      import 'lua-nucleo/string.lua' { 'escape_lua_pattern' }

--    false value - remove key from template (remove blocks also)
--  {table} value - replicate and replace key (process blocks)
-- "string" value - plain replace key with value (ignore blocks)

-- this version and project metamanifest's version must be same
version = 2

dictionary =
{
  PROJECT_NAME = "project-name";

  DEPLOY_SERVER = "server.name.ru";
  DEPLOY_SERVER_DOMAIN = ".2rl";

  -- use this two EXCLUSIVELY for each deploy server
  DEPLOY_SINGLE_MACHINE = { "SAVE_BLOCK" }; -- intended table with string
  DEPLOY_SEVERAL_MACHINES = false;
  -- if "SAVE_BLOCK" used for DEPLOY_SEVERAL_MACHINES then
  --   define DEPLOY_MACHINE - list of name name
  --   use this EXCLUSIVELY for each deploy machine
  --   define DEPLOY_MACHINE_EXTERNAL_URL
  --   define DEPLOY_MACHINE_INTERNAL_URL
  --   define REMOTE_ROCKS_REPO_URL
  --   define DEPLOY_SERVER_HOST (see manifest 03-roles)
  --   define  ROOT_DEPLOYMENT_MACHINE
  -- use examples in generated projects metamanifests as reference

  REMOTE_ROOT_DIR = "-deployment";

  PROJECT_TEAM = "project-name team";
  PROJECT_MAIL = "info@logiceditor.com";
  PROJECT_DOMAIN = "logiceditor.com";

  README_TEXT = [[
project
=======

Copyright (c) 2011-2012, Alexander Gladysh <ag@logiceditor.com>
Copyright (c) 2011-2012, Dmitry Potapov <dp@logiceditor.com>

See file `COPYRIGHT` for the license.

Each third-party rock contents is copyrighted according to its own license.
]];

  COPYRIGHT_TEXT = [[
project License
---------------

project is licensed under the terms of the MIT license reproduced below.
This means that project is free software and can be used for both academic
and commercial purposes at absolutely no cost.

===============================================================================

Copyright (c) 2011-2012 Alexander Gladysh <ag@logiceditor.com>
Copyright (c) 2011-2012 Dmitry Potapov <dp@logiceditor.com>

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the 'Software'), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

===============================================================================

(end of COPYRIGHT)]];

  MAINTAINER = "Alexander Gladysh <agladysh@gmail.com>";
  LICENSE = "Unpublished closed-source!";

  FILE_HEADER = [[
-- See file `COPYRIGHT` for the license and copyright information]];

  IP_ADDRESS = "TODO:Change! 127.0.255.";

  API_TEST_HANDLERS = false;
  MACHINE_NAME = "localhost";
  SERVICE_INDEX = "";

  -- default libs
  PK_TEST = { "SAVE_BLOCK" };
  PK_WEBSERVICE = false;
  PK_CORE_JS_LIB = false;
  PK_LOGICEDITOR_LIB = false;
  PK_ADMIN = false;

  API_NAME = "api";
  -- use this EXCLUSIVELY for each api service
  API_NAME_IP = "3";
  API_NAME_SHORT = "API";

  JOINED_WSAPI = "wsapi";
  -- use this EXCLUSIVELY for each joined api service
  JOINED_WSAPI_IP = "4";
  JOINED_WSAPI_SHORT = "WSA";

  STATIC_NAME = "static";
  STATIC_NAME_IP = "5";

  SERVICE_NAME = "service-name";
  SERVICE_NAME_SHORT = "SVN";
  SERVICE_FCGI_CHILDREN = "10";
  REDIS_BASE_PORT = "6379";
  REDIS_BASE_HOST = "pk-billing-redis-system";

  -- TODO: make redis deploy params as DEPLOY_SERVER subdictionary
  REDIS_BASE_PORT_DEPLOY = "6379";
  REDIS_BASE_HOST_DEPLOY = "pk-billing-redis-system";

  REDIS_BASE = "system";
  REDIS_BASE_NUMBER = "1";
  REDIS_BASE_NUMBER_DEPLOY = "1";

  CLUSTER_NAME =
  {
    "localhost-ag";
    "localhost-dp";
  };

  -- TODO: obsolete, rocks/ related, remove later
  SUBPROJ_NAME = { "pk", "project" };

  KEEP_LOGS_DAYS = false; --{ "30" };

  TASK_DB_NAME = false;
  HAS_TASK_PROCESSOR = false;

  ROBOTS_TXT = [[
User-agent: *
Disallow: /]];

  EMPTY_LISTEN = false;
  NORMAL_LISTEN = { "SAVE_BLOCK" };
  SUBTREE = "";
  ROCKSPEC_DEPENDENCIES = false;
  SHELLENV_LOGFLUSH = "EVERY_N_SECONDS"; -- another value: "ALWAYS"
  DOES_IT_WORK = "";
}
dictionary.PROJECT_LIBDIR = dictionary.PROJECT_NAME .. "-lib"
dictionary.PROJECT_LIB_ROCK = dictionary.PROJECT_NAME .. ".lib"
dictionary.MYSQL_BASES = false
dictionary.MYSQL_BASES_DEPLOY_CFG = false
dictionary.MYSQL_BASES_CFG = false
dictionary.REDIS_BASES_CFG =
    [[system = { address = { host = "]] .. dictionary.PROJECT_NAME
 .. [[-redis-system", port = 6379 }, database = 5 }]]

dictionary.ADMIN_CONFIG =
  [[--No admin settings]]

dictionary.APPLICATION_CONFIG =
  [[--No application settings]]

-- files and directories that will be ignored on project generation
ignore_paths =
{
  "server/lib/";
  "server/PROJECT_NAME-lib/schema/client-api/lib/";
}

wrapper =
{
  -- how values must be wrapped in text to be replaces, eg. #{PROJECT_NAME}
  data  =    { left = "#{"; right = "}"; };

  -- data with procedure eg. #{ESCAPE(PROJECT_NAME)}
  modificator = { left = "("; right = ")"; };

  -- how blocks to be replicated must be wrapped in text
  block =
  {
    top    = { left = "--[[BLOCK_START:"; right = "]]"; };
    bottom = { left = "--[[BLOCK_END:";   right = "]]"; };
  };

  -- how values must be wrapped in file names, eg. lib-%+PROJECT_NAME+.lua
  fs = { left = "%+"; right = "+"; };
}

modificators =
{
  ESCAPED = function(input)
    return escape_lua_pattern(input)
  end;
  UNDERLINE = function(input)
    return input:gsub("-", "_")
  end;
  URLIFY = function(input)
    return input:gsub("_", "-")
  end;
}
