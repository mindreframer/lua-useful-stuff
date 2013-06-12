--------------------------------------------------------------------------------
-- exports.lua: utilities to work with list-exports code
--------------------------------------------------------------------------------

local pairs, select
    = pairs, select

--------------------------------------------------------------------------------

local tijoin_many
      = import 'lua-nucleo/table-utils.lua'
      {
        'tijoin_many'
      }

--------------------------------------------------------------------------------

local merge_exports = function(...)
  local result = { }
  for i = 1, select("#", ...) do
    for name, files in pairs((select(i, ...))) do
      result[name] = tijoin_many(result[name] or { }, files)
    end
  end
  return result
end

--------------------------------------------------------------------------------

return
{
  merge_exports = merge_exports;
}
