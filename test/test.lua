package.cpath = "./?.so"
package.path = string.format("src/?.lua;test/?.lua;%s", package.path)

local postgres = require "postgres"

local config    = require "test_config"
local conn, err = postgres.connection(config.connection_string)
if err then error(err) end

local function emit(query)
  local result, err = conn:execute(query)
  if not result then error(err) end
  return result
end

context("Postgres SCM Rockspec", function()
  test("should be a valid Lua file", function()
    assert_not_error(function()
      loadfile("rockspecs/postgres-scm-1.rockspec")()
    end)
  end)
end)

context("Top-level module functions", function()

  test("should get driver version", function()
    assert_match("%d%.%d%.%d", postgres.version())
  end)

  test("should get a new connection", function()
    assert_not_nil(postgres.connection())
  end)

  test("should open connection", function()
    local conn = postgres.connection("dbname=postgres host=localhost")
    assert_true(conn:open())
  end)

  test("should return false and error if connection fails", function()
    local conn = postgres.connection("dbname=ppostgres host=localhost")
    local ok, err = conn:open()
    assert_false(ok)
    assert_equal("string", type(err))
  end)
end)


context("A connection", function()
  local result, err = conn:execute(config.drop_table)
  if err then error(err) end
  local result, err = conn:execute(config.create_table)
  if err then error(err) end

  before(function()
    emit "insert into people (name) values ('Joe Schmoe')"
  end)

  after(function()
    emit "delete from people"
    emit "deallocate all"
  end)

  it("should query", function()
    local result = emit "select count(*) from people"
    local row = result:fetch()
    assert_equal('1', row[1])
  end)

  it("should query with params", function()
    local result, err = conn:execute("select count(*) from people where 1 = $1", 1)
    if err then error(err) end
    local row = result:fetch()
    assert_equal('1', row[1])
  end)

  it("should query with multiple params", function()
    local result, err = conn:execute("select count(*) from people where 1 = $1 and 2 = $2", {1, 2})
    if err then error(err) end
    local row = result:fetch()
    assert_equal('1', row[1])
  end)
end)

context("A result", function()

  local result
  local query = "select id, name from people order by id asc"

  before(function()
    emit "insert into people (name) values ('Joe Schmoe')"
    emit "insert into people (name) values ('John Doe')"
    emit "insert into people (name) values ('Jim Beam')"
  end)

  after(function()
    emit "delete from people"
    emit "deallocate all"
  end)

  it("output of fetch should be 1-indexed array", function()
    result = emit(query)
    local row = result:fetch()
    assert_equal("Joe Schmoe", row[2])
  end)

  it("output of fetch_assoc should be an associative array", function()
    result = emit(query)
    local row = result:fetch_assoc()
    assert_equal("Joe Schmoe", row.name)
  end)

  it("should get the number of rows", function()
    result = emit(query)
    assert_equal(3, result:num_rows())
    assert_equal(3, #result)
  end)

  it("should be freeable", function()
    result = emit(query)
    result:free()
    assert_error(function() result:fetch() end)
  end)

end)

context("A field", function()

  local field

  before(function()
    emit "insert into people (name) values ('Joe Schmoe')"
    local result = emit("SELECT id, name FROM people")
    local fields = result:fields()
    field = fields[2]
  end)

  after(function()
    emit "delete from people"
  end)

  it("should have a name", function()
    assert_equal("name", field:name())
  end)

  it("should have a number", function()
    assert_equal(1, field:number())
  end)

  it("should have a table_oid", function()
    assert_equal("number", type(field:table_oid()))
  end)

  it("should have a table column number", function()
    assert_equal(2, field:table_column_number())
  end)

  it("should indicate if it's binary", function()
    assert_false(field:is_binary())
  end)

  it("should have a type oid", function()
    assert_equal("number", type(field:type_oid()))
  end)

  it("should have a type name", function()
    assert_equal("varchar", field:type_name())
  end)

  it("should have a table name", function()
    assert_equal("people", field:table_name())
  end)

  it("should have a size", function()
    assert_equal(-1, field:size())
  end)

  it("should have a modifier", function()
    assert_equal(104, field:modifier())
  end)
end)
