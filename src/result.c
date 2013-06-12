/***
A Postgres result.
Postgres results respond to the __len and __call metamethods, so it's possible to
perform most useful operations on a result without directly invoking methods.
The example below shows the recommended way to access the rows in a result.

<h3>Example:</h3>
<pre class="example">
local result = conn:execute("SELECT * FROM members LIMIT 10")
assert(10 == #result)
for row, index in result do
  print(string.format("Info for result %d:", index))
  print(row.id, row.name, row.email)
end
</pre>
Lua Postgres also sets a __gc metamethod on results, so there usually is no
need to free the result when you're done with it. Lua's garbage collection
will take care of this automatically. However, you can manually free the result
if you choose.

@module postgres.result
*/
#include <string.h>
#include <ctype.h>
#include "postgres.h"

static result* get_result(lua_State *L) {
    return (result *) luaL_checkudata(L, 1, LPG_RESULT_METATABLE);
}

static void validate_open(lua_State *L, result *res) {
    if (res->state != LPG_RESULT_OPEN) {
        luaL_error(L, LPG_RESULT_CLOSED_ERROR);
    }
}

/// Frees the memory used by a result. After invoking free(), any attempt to
// to perform operations on the result will raise an error. Note that this is
// normally invoked directly by Lua when result is garbage collected, so there
// is often no need to invoke this manually.
// @function free
static int result_gc(lua_State *L) {
    result *res = get_result(L);
    PQclear(res->pg_result);
    res->pg_result   = NULL;
    res->state       = LPG_RESULT_CLOSED;
    return 0;
}

/**
 * While iterating through a row, push each field value onto a previously
 * initialized Lua table.
 */
static void push_value(lua_State *L, result *res, int i) {
    if (PQgetisnull(res->pg_result, res->current_row, i-1)) {
        lua_pushnil(L);
    }
    else {
        lua_pushstring(L, PQgetvalue(res->pg_result, res->current_row, i-1));
    }
}

// All result_* functions are exported to Lua.

/// Fetches a row numerically, and advances the internal pointer to the next row.
// @function fetch
// @return A table
// @usage
// local result, err = conn:execute("SELECT name FROM members LIMIT 10")
// if err then error(err) end
// for i = 1, #result do
//   local row = result:fetch()
//   print(row[1]) -- prints the name
// end
static int result_fetch(lua_State *L) {
    int i;
    result *res = get_result(L);
    validate_open(L, res);
    if (res->current_row >= res->num_tuples) {
        lua_pushnil(L);
        return 1;
    }
    lua_newtable(L);
    for (i = 1; i <= res->num_fields; i++) {
        push_value(L, res, i);
        lua_rawseti(L, -2, i);
    }
    res->current_row++;
    return 1;
}

// Fetches a row as an associative array, and advances the internal pointer to the next row.
// @function fetch_assoc
// @return A table
// @usage
// local result, err = conn:execute("SELECT name FROM members LIMIT 10")
// if err then error(err) end
// for i = 1, #result do
//   local row = result:fetch_assoc()
//   print(row.name)
// end
static int result_fetch_assoc(lua_State *L) {
    int i;
    result *res = get_result(L);
    validate_open(L, res);
    if (res->current_row >= res->num_tuples) {
        lua_pushnil(L);
        return 1;
    }
    lua_newtable(L);
    for (i = 1; i <= res->num_fields; i++) {
        lua_pushstring(L, PQfname(res->pg_result, i-1));
        push_value(L, res, i);
        lua_rawset(L, -3);
    }
    res->current_row++;
    return 1;
}

/// Gets the number of tuples in the result. You can also invoke this method with
// the length operator (#).
// @function num_rows
// @return A number
// @usage
// assert(10 == #result)
// assert(10 == result:num_rows())
static int result_num_tuples(lua_State *L) {
    result *res = get_result(L);
    validate_open(L, res);
    lua_pushinteger(L, res->num_tuples);
    return 1;
}

/// Gets an array of fields in the result set.
// @function fields
// @return A table
static int result_fields(lua_State *L) {
    int i;
    result *res = get_result(L);
    validate_open(L, res);
    lua_newtable(L);
    for (i = 0; i < res->num_fields; i++) {
        new_field(L, res, i, PQfname(res->pg_result, i));
        lua_rawseti(L, 2, i+1);
    }
    return 1;
}

static int result_call(lua_State *L) {
    result *res = get_result(L);
    validate_open(L, res);
    result_fetch_assoc(L);
    lua_pushinteger(L, res->current_row);
    return 2;
}

static const luaL_Reg methods[] = {
    {"fetch",       result_fetch},
    {"fetch_assoc", result_fetch_assoc},
    {"num_rows",    result_num_tuples},
    {"free",        result_gc},
    {"fields",      result_fields},
    {NULL, NULL}
};

// Public functions

int new_result(lua_State *L, connection *conn, PGresult *pg_result) {
    result *r = ((result *) (lua_newuserdata(L, sizeof(result))));
    luaL_getmetatable(L, LPG_RESULT_METATABLE);
    lua_setmetatable(L, -2);
    r->conn        = conn;
    r->pg_result   = pg_result;
    r->current_row = 0;
    r->num_fields  = PQnfields(pg_result);
    r->num_tuples  = PQntuples(pg_result);
    r->state       = LPG_RESULT_OPEN;
    return 1;
}

void register_result_methods(lua_State *L) {
    luaL_newmetatable(L, LPG_RESULT_METATABLE);
    lua_pushvalue(L, -1);
    lua_setfield(L, -2, "__index");
    luaL_register(L, NULL, methods);
    lua_pushcfunction(L, result_gc);
    lua_setfield(L, -2, "__gc");
    lua_pushcfunction(L, result_num_tuples);
    lua_setfield(L, -2, "__len");
    lua_pushcfunction(L, result_call);
    lua_setfield(L, -2, "__call");
    lua_pop(L, 2);
}
