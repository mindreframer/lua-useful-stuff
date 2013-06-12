local config = {
  connection =  {
    host    = "localhost",
    dbname  = "lua_postgres_test",
    user    = "postgres",
    options = '--client_encoding=UTF-8'
  },
  drop_table   = "drop table if exists people",
  create_table = [=[
   create table people (
    id serial not null primary key,
    name varchar(100)
   )
  ]=]
}

local connection_string = function()
  local buffer = {}
  for k, v in pairs(config.connection) do
    table.insert(buffer, string.format("%s=%s", k, string.format("'%s'", v)))
  end
  return table.concat(buffer, " ")
end

config.connection_string = connection_string()
return config
