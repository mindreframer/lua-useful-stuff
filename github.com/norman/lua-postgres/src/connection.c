/***
A Postgres connection.

@module postgres.connection
*/
#include "postgres.h"

static connection* get_connection(lua_State *L) {
    return (connection *) luaL_checkudata(L, 1, LPG_CONNECTION_METATABLE);
}

static int connect(lua_State *L, connection *conn) {
    PGconn *pg_conn;
    pg_conn = PQconnectdb(conn->connect_string);
    if (PQstatus(pg_conn) != CONNECTION_OK) {
        conn->state   = LPG_CONN_FAILED;
        lua_pushboolean(L, 0);
        lua_pushstring(L, PQerrorMessage(pg_conn));
        PQfinish(conn->pg_conn);
        return 0;
    }
    else {
        conn->pg_conn = pg_conn;
        conn->state   = LPG_CONN_OPEN;
        return 1;
    }
}

static void close(connection *conn) {
    if (conn->state == LPG_CONN_OPEN) {
        conn->state = LPG_CONN_CLOSED;
        PQfinish(conn->pg_conn);
        conn->pg_conn = NULL;
    }
}

// conn_* functions are exported as Lua methods.

/// Opens the connection to the Postgres server.
// @function open
// @return status - Whether or not the connection succeeded.
// @return message - If the connection failed to open, an error message.
// @usage
// local ok, err = conn:open()
// if err then error(err) end
static int conn_open(lua_State *L) {
    connection *conn = get_connection(L);
    luaL_argcheck(L, conn->state != LPG_CONN_OPEN, 1, "connection already open");
    luaL_argcheck(L, conn->state != LPG_CONN_CLOSED, 1, "connection closed");
    if (connect(L, conn)) {
        lua_pushboolean(L, 1);
        lua_pushnil(L);
    }
    return 2;
}

static int conn_close(lua_State *L) {
    connection *conn = get_connection(L);
    luaL_argcheck(L, conn->state != LPG_CONN_NEW, 1, "connection is new");
    luaL_argcheck(L, conn->state != LPG_CONN_CLOSED, 1, "connection already closed");
    close(conn);
    lua_pushnil(L);
    return 1;
}

static int process_result(lua_State *L, connection *conn, PGresult *pg_result) {
    if (pg_result && PQresultStatus(pg_result) == PGRES_COMMAND_OK) {
        /* no tuples returned */
        lua_pushnumber(L, atof(PQcmdTuples(pg_result)));
        PQclear(pg_result);
        return 1;
    }
    else if (pg_result && PQresultStatus(pg_result) == PGRES_TUPLES_OK)
        /* tuples returned */
        return new_result(L, conn, pg_result);
    else {
        /* error */
        PQclear(pg_result);
        lua_pushnil(L);
        lua_pushstring(L, PQerrorMessage(conn->pg_conn));
        return 2;
    }
}

static int execute_without_params(lua_State *L) {
    connection *conn = get_connection(L);
    const char *statement = luaL_checkstring(L, 2);
    PGresult *pg_result = PQexec(conn->pg_conn, statement);
    return process_result(L, conn, pg_result);
}

static int count_params(lua_State *L) {
    int n = 1;
    if (lua_istable(L, 3)) {
        n = lua_objlen(L, 3);
    }
    else if (lua_isnone(L, 3) || lua_isnil(L, 3)) {
        n = 0;
    }
    return n;
}

static char **prepare_params(lua_State *L) {
    int n = count_params(L);
    int i;
    char **params  = NULL;

    if (n == 0) {
        return params;
    }
    else if (lua_istable(L, 3)) {
        params = (char **) malloc(n * sizeof(char *));
        if(params == NULL) {
          fputs("Out of memory.\n", stderr);
          exit(EXIT_FAILURE);
        }
        for (i = 0; i < n; i++) {
            lua_rawgeti(L, 3, i + 1);
            params[i] = (char *) lua_tostring(L, -1);
            lua_pop(L, 1);
        }
    }
    else {
        params = (char **) malloc(sizeof(char *));
        params[0] = (char *) lua_tostring(L, 3);
    }
    return params;
}

static int execute_with_params(lua_State *L) {
    connection *conn      = get_connection(L);
    const char *statement = luaL_checkstring(L, 2);
    int nparams           = count_params(L);
    char **params         = prepare_params(L);

    PGresult *pg_result = PQexecParams(conn->pg_conn, statement, nparams,  NULL,
        (const char * const *) params, NULL, NULL, 0);
    free(params);
    return process_result(L, conn, pg_result);
}

static int lazy_connect(lua_State *L) {
    connection *conn = get_connection(L);

    if (conn->state == LPG_CONN_NEW) {
        if (!connect(L, conn)) {
            return 2;
        }
    }
    return 0;
}

static int send_without_params(lua_State *L) {
    return 0;
}

static int send_with_params(lua_State *L) {
    return 0;
}

static int conn_send(lua_State *L) {
    int result = lazy_connect(L);
    if (result != 0) {
        return result;
    }

    if (lua_gettop(L) == 2) {
        return send_without_params(L);
    } else {
        return send_with_params(L);
    }
}


/// Executes a query.
// @function execute
// @param sql An SQL query
// @param params A single parameter, or a table of parameters
// @return result - A result userdata or nil on failure.
// @return message - If execution failed, an error message
// @usage
// local result, error = conn:execute("SELECT * FROM users WHERE name = $1", "joe")
// local result, error = conn:execute("SELECT * FROM users WHERE name = $1 AND age < $2", {"joe", 100})
static int conn_execute(lua_State *L) {
    int result = lazy_connect(L);
    if (result != 0) {
        return result;
    }

    if (lua_gettop(L) == 2) {
        return execute_without_params(L);
    } else {
        return execute_with_params(L);
    }
}

/**
 * Invoked by Lua when connection is garbage collected.
 */
static int connection_gc(lua_State *L) {
    connection *conn = get_connection(L);
    close(conn);
    return 0;
}

static const luaL_Reg methods[] = {
    {"open",    conn_open},
    {"close",   conn_close},
    {"execute", conn_execute},
    {"send",    conn_send},
    {NULL, NULL}
};

/**
 * Push the methods into the Lua module.
 */
void register_connection_methods(lua_State *L) {
    luaL_newmetatable(L, LPG_CONNECTION_METATABLE);
    lua_pushvalue(L, -1);
    lua_setfield(L, -2, "__index");
    luaL_register(L, NULL, methods);
    lua_pushcfunction(L, connection_gc);
    lua_setfield(L, -2, "__gc");
    lua_pop(L, 2);
}
