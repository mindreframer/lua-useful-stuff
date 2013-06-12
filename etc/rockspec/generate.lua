--------------------------------------------------------------------------------
-- generate.lua: lua-aplicado dumb rockspec generator
-- This file is a part of Lua-Aplicado library
-- Copyright (c) Lua-Aplicado authors (see file `COPYRIGHT` for the license)
--------------------------------------------------------------------------------

pcall(require, 'luarocks.require') -- Ignoring errors

local lfs = require 'lfs'

-- TODO: Reuse copy in lua-aplicado/filesystem.lua
local function find_all_files(path, regexp, dest, mode)
  dest = dest or {}
  mode = mode or false

  assert(mode ~= "directory")

  for filename in lfs.dir(path) do
    if filename ~= "." and filename ~= ".." then
      local filepath = path .. "/" .. filename
      local attr = lfs.attributes(filepath)
      if attr.mode == "directory" then
        find_all_files(filepath, regexp, dest)
      elseif not mode or attr.mode == mode then
        if filename:find(regexp) then
          dest[#dest + 1] = filepath
          -- print("found", filepath)
        end
      end
    end
  end

  return dest
end

local files = find_all_files("lua-aplicado", "^.*%.lua$")
table.sort(files)

-- TODO: Do not forget to update dependencies as needed!
io.stdout:write([[
package = "lua-aplicado"
version = "]] .. (select(1, ...) or "scm-1") .. [["
source = {
   url = "git://github.com/lua-aplicado/lua-aplicado.git",
   branch = "master"
}
description = {
   summary = "A random collection of application level Lua libraries",
   homepage = "http://github.com/lua-aplicado/lua-aplicado",
   license = "MIT/X11"
}
dependencies = {
   "lua >= 5.1",
   "lua-nucleo >= 0.0.1",
   "lua-getdate >= 0.1-1",
   "luafilesystem >= 1.5.0",
   "lbci >= 20090306",
   "luasocket >= 2.0.2",
   "luaposix >= 5.1.23",
   "lpeg",
   "md5"
}
build = {
   type = "none",
   install = {
      lua = {
]])

for i = 1, #files do
  local name = files[i]
  io.stdout:write([[
         []] .. (
          ("%q"):format(
              name:gsub("/", "."):gsub("\\", "."):gsub("%.lua$", "")
            )
        ) .. [[] = ]] .. (("%q"):format(name)) .. [[;
]])
end

io.stdout:write([[
      }
   }
}
]])
io.stdout:flush()
