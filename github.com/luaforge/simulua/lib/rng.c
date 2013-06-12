/*
 * Random number generator (RNG) library for Lua
 * Check license in rng.h
 * $Id: rng.c,v 1.1 2008-08-19 23:36:45 carvalho Exp $
*/

#include <lauxlib.h>
#include <math.h>
#include "rng.h"

LUARNG_API lua_RNG *rng_check (lua_State *L, int pos) {
  lua_RNG *r = NULL;
  if (lua_isnoneornil(L, pos)) return NULL;
  if (pos <= 0 && pos > LUA_REGISTRYINDEX) pos = lua_gettop(L) + pos + 1;
  if (!lua_getmetatable(L, pos)) return NULL;
  /* check current environment first */
  if (lua_rawequal(L, -1, LUA_ENVIRONINDEX))
    r = (lua_RNG *) lua_touserdata(L, (pos < 0) ? pos - 1 : pos);
  else {
    lua_getfield(L, LUA_REGISTRYINDEX, LUARNG_MT);
    if (lua_rawequal(L, -1, -2))
      r = (lua_RNG *) lua_touserdata(L, (pos < 0) ? pos - 2 : pos);
    lua_pop(L, 1); /* LUARNG_MT */
  }
  lua_pop(L, 1); /* mt */
  if (!r) luaL_typerror(L, pos, LUARNG_LIBNAME);
  return r;
}

/* {=================================================================
 *      Class metamethods
 * ==================================================================} */

static int rng__index (lua_State *L) {
  lua_RNG *r = (lua_RNG *) lua_touserdata(L, 1);
  int i;
  if (lua_isnumber(L, 2)) {
    i = luaL_checkinteger(L, 2) - 1; /* zero offset */
    luaL_argcheck(L, i >= 0 && i < LUARNG_MAXSTATES, 2,
        "index out of range");
    lua_pushinteger(L, r->v[i]);
  }
  else
    lua_getfield(L, LUA_ENVIRONINDEX, lua_tostring(L, 2));
  return 1;
}

static int rng__tostring (lua_State *L) {
  lua_pushfstring(L, LUARNG_LIBNAME ": %p", lua_touserdata(L, 1));
  return 1;
}

/* {=================================================================
 *      Class methods
 * ==================================================================} */

static int new_rng (lua_State *L) {
  unsigned long s = luaL_optlong(L, 2, LUARNG_SEED);  /* class table at 1 */
  lua_RNG *r = lua_newuserdata(L, sizeof(lua_RNG));
  init_genrand(r, s);
  lua_pushvalue(L, LUA_ENVIRONINDEX);
  lua_setmetatable(L, -2);
  return 1;
}

static int copy_rng (lua_State *L) {
  lua_RNG *c = rng_check(L, 1);
  lua_RNG *r = (lua_RNG *) lua_newuserdata(L, sizeof(lua_RNG));
  *r = *c;
  return 1;
}

static int check_rng (lua_State *L) {
  int b;
  if ((b = lua_getmetatable(L, 1)) != 0) {
    b &= lua_rawequal(L, -1, LUA_ENVIRONINDEX);
    lua_pop(L, 1); /* mt */
  }
  lua_pushboolean(L, b);
  return 1;
}

static int geti_rng (lua_State *L) {
  lua_RNG *r = rng_check(L, 1);
  lua_pushinteger(L, r->i);
  return 1;
}

static int seed_rng (lua_State *L) {
  lua_RNG *r = rng_check(L, 1);
  init_genrand(r, luaL_optlong(L, 2, LUARNG_SEED));
  return 0;
}

static int seedarray_rng (lua_State *L) {
  lua_RNG *r = rng_check(L, 1);
  unsigned long init_key[LUARNG_MAXSTATES];
  int pos = 0;
  luaL_checktype(L, 2, LUA_TTABLE);
  /* traverse table and store keys in array */
  lua_pushnil(L);
  while (lua_next(L, -2) != 0) {
    init_key[pos++] = luaL_optlong(L, -1, LUARNG_SEED);
    lua_pop(L, 1);
  }
  init_by_array(r, init_key, pos);
  return 0;
}

/* {=================================================================
 *      Main routines
 * ==================================================================} */

static int beta_rng (lua_State *L) {
  lua_RNG *r = rng_check(L, 1);
  lua_Number a = luaL_checknumber(L, 2);
  lua_Number b = luaL_checknumber(L, 3);
  if (a <= 0)
    luaL_error(L, "parameter 1 is nonpositive: %f", a);
  if (b <= 0)
    luaL_error(L, "parameter 2 is nonpositive: %f", b);
  lua_pushnumber(L, genbet(r, a, b));
  return 1;
}

static int chisq_rng (lua_State *L) {
  lua_RNG *r = rng_check(L, 1);
  lua_Number df = luaL_checknumber(L, 2);
  lua_Number xnonc = luaL_optnumber(L, 3, 0);
  if (df <= 0)
    luaL_error(L, "parameter 1 is nonpositive: %f", df);
  if (xnonc < 0)
    luaL_error(L, "parameter 2 is negative: %f", xnonc);
  if (xnonc == 0)
    lua_pushnumber(L, genchi(r, df));
  else
    lua_pushnumber(L, gennch(r, df, xnonc));
  return 1;
}

static int exp_rng (lua_State *L) {
  lua_RNG *r = rng_check(L, 1);
  lua_Number av = luaL_optnumber(L, 2, 1);
  lua_pushnumber(L, genexp(r, av));
  return 1;
}

static int f_rng (lua_State *L) {
  lua_RNG *r = rng_check(L, 1);
  lua_Number dfn = luaL_checknumber(L, 2);
  lua_Number dfd = luaL_checknumber(L, 3);
  lua_Number xnonc = luaL_optnumber(L, 4, 0);
  if (dfn <= 0)
    luaL_error(L, "parameter 1 is nonpositive: %f", dfn);
  if (dfd <= 0)
    luaL_error(L, "parameter 2 is nonpositive: %f", dfd);
  if (xnonc < 0)
    luaL_error(L, "parameter 3 is negative: %f", xnonc);
  if (xnonc == 0)
    lua_pushnumber(L, genf(r, dfn, dfd));
  else
    lua_pushnumber(L, gennf(r, dfn, dfd, xnonc));
  return 1;
}

static int gamma_rng (lua_State *L) {
  lua_RNG *r = rng_check(L, 1);
  lua_Number a = luaL_checknumber(L, 2);
  lua_Number s = luaL_optnumber(L, 3, 1);
  lua_pushnumber(L, gengam(r, s, a));
  return 1;
}

static int norm_rng (lua_State *L) {
  lua_RNG *r = rng_check(L, 1);
  lua_Number av = luaL_optnumber(L, 2, 0);
  lua_Number v = luaL_optnumber(L, 3, 1);
  if (v <= 0) luaL_error(L, "standard deviation is negative: %f", v);
  lua_pushnumber(L, gennor(r, av, v));
  return 1;
}

static int unif_rng (lua_State *L) {
  lua_RNG *r = rng_check(L, 1);
  lua_Number low = luaL_optnumber(L, 2, 0);
  lua_Number high = luaL_optnumber(L, 3, 1);
  if (low > high)
    luaL_error(L, "inconsistent parameters: %f > %f", low, high);
  lua_pushnumber(L, genunf(r, low, high));
  return 1;
}

static int binom_rng (lua_State *L) {
  lua_RNG *r = rng_check(L, 1);
  int n = luaL_checkinteger(L, 2);
  lua_Number p = luaL_checknumber(L, 3);
  if (n < 0)
    luaL_error(L, "parameter 1 is negative: %d", n);
  if (p <= 0 || p >= 1)
    luaL_error(L, "out of range on parameter 2: %f", p);
  lua_pushinteger(L, ignbin(r, n, p));
  return 1;
}

static int nbinom_rng (lua_State *L) {
  lua_RNG *r = rng_check(L, 1);
  int n = luaL_checkinteger(L, 2);
  lua_Number p = luaL_checknumber(L, 3);
  if (n < 0)
    luaL_error(L, "parameter 1 is negative: %d", n);
  if (p <= 0 || p >= 1)
    luaL_error(L, "out of range on parameter 2: %f", p);
  lua_pushinteger(L, ignnbn(r, n, p));
  return 1;
}

static int pois_rng (lua_State *L) {
  lua_RNG *r = rng_check(L, 1);
  lua_Number mu = luaL_checknumber(L, 2);
  lua_pushinteger(L, ignpoi(r, mu));
  return 1;
}

static int unifint_rng (lua_State *L) {
  lua_RNG *r = rng_check(L, 1);
  int low = luaL_optinteger(L, 2, 0);
  int high = luaL_optinteger(L, 3, 0x7ffffffeUL);
  if (low > high)
    luaL_error(L, "inconsistent parameters: %d > %d", low, high);
  lua_pushinteger(L, ignuin(r, low, high));
  return 1;
}

/* {=================================================================
 *      Interface
 * ==================================================================} */

static const luaL_reg rng_lib[] = {
  {"new", new_rng},
  {"copy", copy_rng},
  {"check", check_rng},
  {"geti", geti_rng},
  {"seed", seed_rng},
  {"seedarray", seedarray_rng},
  /* deviates */
  {"beta", beta_rng},
  {"chisq", chisq_rng},
  {"exp", exp_rng},
  {"f", f_rng},
  {"gamma", gamma_rng},
  {"norm", norm_rng},
  {"unif", unif_rng},
  {"binom", binom_rng},
  {"nbinom", nbinom_rng},
  {"pois", pois_rng},
  {"unifint", unifint_rng},
  {NULL, NULL}
};

LUARNG_API int luaopen_rng (lua_State *L) {
  /* luaRNG MT */
  luaL_newmetatable(L, LUARNG_MT);
  /* set as current environment */
  lua_pushvalue(L, -1);
  lua_replace(L, LUA_ENVIRONINDEX);
  /* class table */
  luaL_register(L, LUARNG_LIBNAME, rng_lib);
  /* push constants */
  lua_pushstring(L, LUARNG_VERSION);
  lua_setfield(L, -2, "_VERSION");
  /* push class table as upvalue to __index */
  lua_pushcfunction(L, rng__index);
  lua_pushvalue(L, -2);
  lua_setfenv(L, -2);
  lua_setfield(L, -3, "__index");
  lua_pushcfunction(L, rng__tostring);
  lua_setfield(L, -3, "__tostring");
  lua_pushvalue(L, -2);
  lua_setfield(L, -2, "_MT"); /* push MT */
  /* class MT */
  lua_createtable(L, 0, 2);
  lua_pushcfunction(L, new_rng);
  lua_setfield(L, -2, "__call");
  lua_pushvalue(L, -2); /* class */
  lua_setfield(L, -2, "__metatable"); /* protect */
  lua_setmetatable(L, -2);
  return 1;
}

