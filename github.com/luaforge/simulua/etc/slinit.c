/*
** Initialization of libraries for simulua.c
*/


#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
#include "simulua_lc.h"

#define SIMULUA_HEAPNAME  "binomial"
#define SIMULUA_QUEUENAME "queue"
#define SIMULUA_STACKNAME "stack"
#define SIMULUA_RNGNAME   "rng"
#define SIMULUA_CDFNAME   "cdf"

int luaopen_binomial (lua_State *L);
int luaopen_queue (lua_State *L);
int luaopen_stack (lua_State *L);
int luaopen_rng (lua_State *L);
int luaopen_cdf (lua_State *L);

static const luaL_Reg lualibs[] = {
  {"", luaopen_base},
  {LUA_LOADLIBNAME, luaopen_package},
  {LUA_TABLIBNAME, luaopen_table},
  {LUA_IOLIBNAME, luaopen_io},
  {LUA_OSLIBNAME, luaopen_os},
  {LUA_STRLIBNAME, luaopen_string},
  {LUA_MATHLIBNAME, luaopen_math},
  {LUA_DBLIBNAME, luaopen_debug},
  {NULL, NULL}
};

static const luaL_Reg simulualibs[] = {
  {SIMULUA_HEAPNAME, luaopen_binomial},
  {SIMULUA_QUEUENAME, luaopen_queue},
  {SIMULUA_STACKNAME, luaopen_stack},
  {SIMULUA_RNGNAME, luaopen_rng},
  {SIMULUA_CDFNAME, luaopen_cdf},
  {NULL, NULL}
};


void sluaL_openlibs (lua_State *L) {
  const luaL_Reg *lib = lualibs;
  for (; lib->func; lib++) {
    lua_pushcfunction(L, lib->func);
    lua_pushstring(L, lib->name);
    lua_call(L, 1, 0);
  }
  /* register other libs */
  lua_getglobal(L, "package");
  lua_getfield(L, -1, "preload");
  luaL_register(L, NULL, simulualibs);
  lua_pop(L, 2); /* package and package.preload */
  /* simulua */
  if (luaL_loadbuffer(L, simulua_lc, simulua_lc_len, "simulua")
    || lua_pcall(L, 0, 0, 0)) lua_error(L);
}

