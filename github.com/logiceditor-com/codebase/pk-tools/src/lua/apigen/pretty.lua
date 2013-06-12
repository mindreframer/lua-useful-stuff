--------------------------------------------------------------------------------
-- apigen/pretty.lua: prettyprint facilities
-- This file is a part of pk-tools library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------
-- TODO: Overhead! Avoid spawning extra processes!
--------------------------------------------------------------------------------

local log, dbg, spam, log_error
      = import 'pk-core/log.lua' { 'make_loggers' } (
          "apigen/apidoc", "ADC"
        )

--------------------------------------------------------------------------------

local assert = assert
local io_popen = io.popen

--------------------------------------------------------------------------------

local posix = require 'posix'

--------------------------------------------------------------------------------

local arguments,
      optional_arguments,
      method_arguments
      = import 'lua-nucleo/args.lua'
      {
        'arguments',
        'optional_arguments',
        'method_arguments',
        'eat_true'
      }

local tpretty
      = import 'lua-nucleo/tpretty.lua'
      {
        'tpretty'
      }

local write_file
      = import 'lua-aplicado/filesystem.lua'
      {
        'write_file'
      }

--------------------------------------------------------------------------------

-- TODO: Move somewhere to lua-aplicado
-- TODO: Do not fail, return nil, err instead
local shell_filter = function(command, tmpdir, src)
  arguments(
      "string", command,
      "string", tmpdir,
      "string", src
    )
  dbg("prettyprinting xml in", tmpdir)
  assert(os.execute("mkdir -p '" .. tmpdir .. "'") == 0)

  local src_filename = tmpdir .. "/src.bin"

  assert(write_file(src_filename, src))

  local f = assert(
      io_popen(
          command:format(src_filename),
          "r"
        )
    )
  local pretty = f:read("*a")
  f:close()
  f = nil

  dbg("removing", tmpdir)
  assert(os.execute("rm -rf '" .. tmpdir .. "'") == 0)

  return pretty
end

--------------------------------------------------------------------------------

local prettyprint_lua = function(src)
  arguments("table", src)
  return tpretty(src, "  ", 80) -- TODO: Improve!
end

local prettyprint_json = function(src)
  arguments("string", src)

  return assert(
      shell_filter(
          "cat '%s'"
       .. " | python -mjson.tool",
          "/tmp/pk-apigen-doc-json-"..posix.getpid().pid,
          src
        )
    ):gsub("%s+\n", "\n") -- trim trailing spaces
end

local prettyprint_xml = function(src)
  arguments("string", src)

  return assert(
      shell_filter(
          "tidy"
       .. " -quiet --indent-cdata yes -indent"
       .. " -wrap 80 -xml -asxml --indent-attributes yes"
       .. " '%s'",
          "/tmp/pk-apigen-doc-xml-"..posix.getpid().pid,
          src
        )
    ):gsub("%s+\n", "\n") -- trim trailing spaces
end

--------------------------------------------------------------------------------

return
{
  prettyprint_lua = prettyprint_lua;
  prettyprint_json = prettyprint_json;
  prettyprint_xml = prettyprint_xml;
}
