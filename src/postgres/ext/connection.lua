local postgres = require "postgres.core"
local connection_methods = {}

function connection_methods:meta_info(table_name)
  local sql = [=[
    SELECT
      a.attname    "name",
      a.attnum     num,
      t.typname    "type",
      a.attlen     len,
      a.attnotnull not_null,
      a.atthasdef  has_default,
      a.attndims   array_dims
    FROM pg_class as c, pg_attribute a, pg_type t, pg_namespace n
    WHERE a.attnum > 0
    AND a.attrelid = c.oid
    AND c.relname = $1
    AND c.relnamespace = n.oid
    AND n.nspname = $2
    AND a.atttypid = t.oid
    ORDER BY a.attnum
  ]=]
  local table, namespace = table_name:match("^([^.]+)%.([^.]+)")
  if not table then
    table     = table_name
    namespace = "public"
  end
  local result, err = self:execute(sql, {table, namespace})
  if err then error(err) end
  return result
end

local mt = postgres.connection_metatable()
local oi = mt.__index
mt.__index = function(t, k)
  return connection_methods[k] or oi[k]
end