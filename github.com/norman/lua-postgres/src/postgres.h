#include <stdlib.h>
#include <lua.h>
#include <lauxlib.h>

/*
 * Compatibility with Lua 5.2
*/
#if (LUA_VERSION_NUM == 502)
#undef lua_objlen
#define lua_objlen  lua_rawlen

#undef luaL_register
#define luaL_register(L, n, f) { luaL_setfuncs(L, f, 0); }
#endif

#include <libpq-fe.h>

#define LPG_VERSION "0.0.1"
#define LPG_CONNECTION_METATABLE "Lua Postgres Connection"
#define LPG_RESULT_METATABLE     "Lua Postgres Result"
#define LPG_FIELD_METATABLE      "Lua Postgres Field"
#define LPG_FIELD_TYPE_TABLE     "Lua Postgres Field Types Table"
#define LPG_RESULT_CLOSED_ERROR  "Attempted to access a closed result"

#define LPG_FIELD_TABLE_NAME_QUERY "SELECT relname FROM pg_class WHERE oid = %d"
#define LPG_FIELD_TYPE_NAME_QUERY  "SELECT typname FROM pg_type WHERE oid = %d"

enum connection_state { LPG_CONN_OPEN, LPG_CONN_CLOSED, LPG_CONN_NEW, LPG_CONN_FAILED };
enum result_state { LPG_RESULT_OPEN, LPG_RESULT_CLOSED };

typedef struct {
    PGconn     *pg_conn;
    const char *connect_string;
    int        state;
} connection;

typedef struct {
    connection *conn;
    PGresult   *pg_result;
    int        current_row, num_fields, num_tuples, state;
} result;

typedef struct {
  result     *result;
  int        number;
  const char *name;
} field;

void register_connection_methods(lua_State *L);
void register_result_methods(lua_State *L);
void register_field_methods(lua_State *L);

int new_result(lua_State *L, connection *conn, PGresult *result);
int new_field(lua_State *L, result *result, int number, const char *name);
