/***
A basic Postgres driver for Lua.

@module postgres
*/
#include "postgres.h"

/// Get the driver version.
// @function version
// @return A version string, e.g. "0.0.1".
static int module_version(lua_State *L) {
    lua_pushstring(L, LPG_VERSION);
    return 1;
}

/// Creates a new connection object. Note that this does not immediately connect
// to the database, it simply creates a handle. You can then invoke connection.open
// to make the connection immediately. If you do not open the connection manually,
// lua-postgres will establish a connection the first time it is needed.
// @function connection
// @param connection_string A Postgres connection string. See the <a
//   href="http://www.postgresql.org/docs/9.0/static/libpq-connect.html">documentation
//   for libpq</a> for the full list of values that can be in the string.
// @return A Postgres connection
// @usage
// local conn = postgres.connection('dbname=my_db host=localhost user=postgres')
static int module_connection(lua_State *L) {
    const char *connect_string = luaL_optstring(L, 1, "dbname = postgres");
    connection *p = ((connection *) (lua_newuserdata(L, sizeof(connection))));
    luaL_getmetatable(L, LPG_CONNECTION_METATABLE);
    lua_setmetatable(L, -2);
    p->pg_conn        = NULL;
    p->state          = LPG_CONN_NEW;
    p->connect_string = connect_string;
    return 1;
}

static int module_connection_metatable(lua_State *L) {
    luaL_getmetatable(L, LPG_CONNECTION_METATABLE);
    return 1;
}

static int module_result_metatable(lua_State *L) {
    luaL_getmetatable(L, LPG_RESULT_METATABLE);
    return 1;
}

static int module_field_metatable(lua_State *L) {
    luaL_getmetatable(L, LPG_FIELD_METATABLE);
    return 1;
}

/**
 * Top-level module functions.
 */
static const struct luaL_Reg functions [] = {
    {"version", module_version},
    {"connection", module_connection},
    {"connection_metatable", module_connection_metatable},
    {"result_metatable", module_result_metatable},
    {"field_metatable", module_field_metatable},
    {NULL, NULL}
};

void register_module_functions(lua_State *L) {
    luaL_register(L, "postgres", functions);
}

/**
 * Lua module setup.
 */
int luaopen_postgres_core(lua_State *L) {
    register_connection_methods(L);
    register_result_methods(L);
    register_field_methods(L);
    register_module_functions(L);
    return 1;
}
