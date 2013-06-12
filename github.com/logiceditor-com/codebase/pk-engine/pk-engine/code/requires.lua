--------------------------------------------------------------------------------
-- require.lua: information on 3rd party Lua modules
-- This file is a part of pk-engine library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------

-- Map of global symbol name to module name where it is defined
local REQUIRE_GLOBALS =
{
  copas = "copas";
  posix = "posix";
  socket = "socket";
  xavante = "xavante";
  luabins = "luabins";
  wsapi = "wsapi";
  md5 = "md5";
  luasql = "luasql";
  uuid = "uuid";
  lfs = "lfs";
  base64 = "base64";
  iconv = "iconv";
  unicode = "unicode";
  sidereal = "sidereal"; -- TODO: Remove this
  geoip = "geoip";
  hiredis = "hiredis";
  zmq = "zmq";
  lxp = "lxp";
  ssl = "ssl";  -- this is from "luasec"
  ltn12 = "ltn12";
}

--------------------------------------------------------------------------------

return
{
  REQUIRE_GLOBALS = REQUIRE_GLOBALS;
}
