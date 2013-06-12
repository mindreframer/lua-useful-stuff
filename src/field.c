/// A field in a result.
//
// This module provides meta information about result set fields.
//
// @module postgres.field
#include "postgres.h"

int new_field(lua_State *L, result *result, int number, const char *name) {
    field *f = lua_newuserdata(L, sizeof(field));
    luaL_getmetatable(L, LPG_FIELD_METATABLE);
    lua_setmetatable(L, -2);
    f->result    = result;
    f->number    = number;
    f->name      = name;
    return 1;
}

static field* get_field(lua_State *L) {
    return (field *) luaL_checkudata(L, 1, LPG_FIELD_METATABLE);
}

/// The field's name.
// @function name
static int field_name(lua_State *L) {
    field *f = get_field(L);
    lua_pushstring(L, f->name);
    return 1;
}

/// The field's number in the result set. Note that this is 0-based, rather than
// 1-based because it is the value directly provided by Postgres.
// @function number
static int field_number(lua_State *L) {
    field *f = get_field(L);
    lua_pushinteger(L, f->number);
    return 1;
}

/// The oid of the table that the field comes from.
// @function table_oid
static int field_table_oid(lua_State *L) {
    field *f = get_field(L);
    lua_pushnumber(L, PQftable(f->result->pg_result, f->number));
    return 1;
}

/// The column number from the table that the field comes from. From the libpq
// manual:
// <blockquote>
// Returns the column number (within its table) of the column making up the
// specified query result column. Query-result column numbers start at 0, but table
// columns have nonzero numbers. Zero is returned if the column number is out of
// range, or if the specified column is not a simple reference to a table column,
// or when using pre-3.0 protocol.
// </blockquote>
// @function column_number
static int field_table_column_number(lua_State *L) {
    field *f = get_field(L);
    lua_pushnumber(L, PQftablecol(f->result->pg_result, f->number));
    return 1;
}

/// Whether the field is binary.
// @function is_binary
static int field_is_binary(lua_State *L) {
    field *f = get_field(L);
    lua_pushboolean(L, PQfformat(f->result->pg_result, f->number) == 1);
    return 1;
}

/// The oid of the field's type.
// @function type_oid
static int field_type_oid(lua_State *L) {
    field *f = get_field(L);
    lua_pushnumber(L, PQftype(f->result->pg_result, f->number));
    return 1;
}

static void do_oid_query(lua_State *L, field *f, const char *query, Oid oid) {
    lua_pushfstring(L, query, oid);
    char *sql = (char *) lua_tolstring(L, -1, NULL);
    PGresult *pg_result = PQexec(f->result->conn->pg_conn, sql);
    if (PQresultStatus(pg_result) != PGRES_TUPLES_OK) {
        luaL_error(L, PQerrorMessage(f->result->conn->pg_conn));
    }
    lua_pushstring(L, PQgetvalue(pg_result, 0, 0));
    PQclear(pg_result);
}

// The name field type. This is often more useful than just getting the oid.
// Note that each time this is invoked, a query is performed. If you need to
// call this method many times, it's a good candidate for memoization.
// @function type_name
static int field_type_name(lua_State *L) {
    field *f = get_field(L);
    do_oid_query(L, f, LPG_FIELD_TYPE_NAME_QUERY, PQftype(f->result->pg_result, f->number));
    return 1;
}

// The name of the table that the field comes from. This is often more useful
// than just getting the oid. Note that each time this is invoked, a query is
// performed. If you need to call this method many times, it's a good candidate
// for memoization.
// @function table_name
static int field_table_name(lua_State *L) {
    field *f = get_field(L);
    do_oid_query(L, f, LPG_FIELD_TABLE_NAME_QUERY, PQftable(f->result->pg_result, f->number));
    return 1;
}

/// The field's size. From the libpq manual:
// <blockquote>
// PQfsize returns the space allocated for this column in a database row, in other
// words the size of the server's internal representation of the data type.
// (Accordingly, it is not really very useful to clients.) A negative value
// indicates the data type is variable-length.
// </blockquote>
// @function size
static int field_size(lua_State *L) {
    field *f = get_field(L);
    lua_pushnumber(L, PQfsize(f->result->pg_result, f->number));
    return 1;
}

/// The field's modifier, if any. From the libpq manual:
// <blockquote>
// The interpretation of modifier values is type-specific; they typically indicate
// precision or size limits. The value -1 is used to indicate "no information
// available". Most data types do not use modifiers, in which case the value is
// always -1.
// </blockquote>
// @function modifier
static int field_modifier(lua_State *L) {
    field *f = get_field(L);
    lua_pushnumber(L, PQfmod(f->result->pg_result, f->number));
    return 1;
}

static const luaL_Reg methods[] = {
    {"is_binary",           field_is_binary},
    {"modifier",            field_modifier},
    {"name",                field_name},
    {"number",              field_number},
    {"size",                field_size},
    {"table_column_number", field_table_column_number},
    {"table_oid",           field_table_oid},
    {"type_oid",            field_type_oid},
    {"type_name",           field_type_name},
    {"table_name",          field_table_name},
    {NULL, NULL}
};

void register_field_methods(lua_State *L) {
    luaL_newmetatable(L, LPG_FIELD_METATABLE);
    lua_pushvalue(L, -1);
    lua_setfield(L, -2, "__index");
    luaL_register(L, NULL, methods);
    /* lua_pushcfunction(L, result_gc); */
    /* lua_setfield(L, -2, "__gc"); */
    lua_pop(L, 2);
}
