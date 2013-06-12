/*
 * Stacks
 * Check license at the bottom of the file
 * $Id: stack.c,v 1.1 2008-08-19 23:36:45 carvalho Exp $
*/

#include <lua.h>
#include <lauxlib.h>

typedef struct stackstc {
  int top;
} stack;

static stack *checkstack (lua_State *L, int pos) {
  stack *s = NULL;
  if (lua_isnoneornil(L, pos) || !lua_getmetatable(L, pos)) return NULL;
  if (lua_rawequal(L, -1, LUA_ENVIRONINDEX))
    s = (stack *) lua_touserdata(L, pos);
  lua_pop(L, 1); /* MT */
  return s;
}

static int pop (lua_State *L, stack *s, int nodelete) {
  if (s->top == 0) lua_pushnil(L);
  else {
    lua_getfenv(L, 1);
    lua_rawgeti(L, -1, s->top);
    if (!nodelete) {
      lua_pushnil(L);
      lua_rawseti(L, -3, s->top);
      s->top--;
    }
  }
  return 1;
}

/* =======   methods   ======= */
static int stack_new (lua_State *L) {
  stack *s = (stack *) lua_newuserdata(L, sizeof(stack));
  s->top = 0;
  lua_pushvalue(L, LUA_ENVIRONINDEX);
  lua_setmetatable(L, -2);
  lua_newtable(L);
  lua_setfenv(L, -2);
  return 1;
}

static int stack_push (lua_State *L) {
  stack *s = checkstack(L, 1);
  lua_settop(L, 2); /* stack, element */
  if (lua_isnil(L, 2)) return 0;
  lua_getfenv(L, 1);
  lua_pushvalue(L, 2);
  lua_rawseti(L, -2, ++(s->top));
  return 0;
}

static int stack_pop (lua_State *L) {
  return pop(L, checkstack(L, 1), lua_toboolean(L, 2));
}

static int stack_top (lua_State *L) {
  return pop(L, checkstack(L, 1), 1);
}

static int stack_isempty (lua_State *L) {
  stack *s = checkstack(L, 1);
  lua_pushboolean(L, s->top == 0);
  return 1;
}


static int stack_len (lua_State *L) {
  stack *s = (stack *) lua_touserdata(L, 1);
  lua_pushinteger(L, s->top);
  return 1;
}

static int stack_tostring (lua_State *L) {
  lua_pushfstring(L, "stack: %p", lua_touserdata(L, 1));
  return 1;
}


static const luaL_reg stack_func[] = {
  {"push", stack_push},
  {"into", stack_push}, /* alias */
  {"pop", stack_pop},
  {"top", stack_top},
  {"isempty", stack_isempty},
  {NULL, NULL}
};

int luaopen_stack (lua_State *L) {
  lua_newtable(L); /* class */
  lua_newtable(L); /* new environment */
  lua_pushvalue(L, -1);
  lua_replace(L, LUA_ENVIRONINDEX);
  lua_pushcfunction(L, stack_tostring);
  lua_setfield(L, -2, "__tostring");
  lua_pushcfunction(L, stack_len);
  lua_setfield(L, -2, "__len");
  lua_pushvalue(L, -2);
  lua_setfield(L, -2, "__index");
  lua_pop(L, 1); /* env/metatable */
  luaL_register(L, NULL, stack_func);
  lua_pushcfunction(L, stack_new);
  return 1; /* new stack */
}


/*
Copyright (c) 2008 Luis Carvalho

Permission is hereby granted, free of charge, to any person
obtaining a copy of this software and associated documentation files
(the "Software"), to deal in the Software without restriction,
including without limitation the rights to use, copy, modify,
merge, publish, distribute, sublicense, and/or sell copies of the
Software, and to permit persons to whom the Software is furnished
to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/
