/*
 * Queues
 * Check license at the bottom of the file
 * $Id: queue.c,v 1.1 2008-08-19 23:36:38 carvalho Exp $
*/

#include <lua.h>
#include <lauxlib.h>

typedef struct queuestc {
  int head;
  int tail;
} queue;

#define len(q) ((q)->tail - (q)->head + 1)

static queue *checkqueue (lua_State *L, int pos) {
  queue *q = NULL;
  if (lua_isnoneornil(L, pos) || !lua_getmetatable(L, pos)) return NULL;
  if (lua_rawequal(L, -1, LUA_ENVIRONINDEX))
    q = (queue *) lua_touserdata(L, pos);
  lua_pop(L, 1); /* MT */
  return q;
}

static int retrieve (lua_State *L, queue *q, int nodelete) {
  if (q->tail < q->head) lua_pushnil(L);
  else {
    lua_getfenv(L, 1);
    lua_rawgeti(L, -1, q->head);
    if (!nodelete) {
      lua_pushnil(L);
      lua_rawseti(L, -3, q->head);
      q->head++;
    }
  }
  return 1;
}

/* =======   methods   ======= */
static int queue_new (lua_State *L) {
  queue *q = (queue *) lua_newuserdata(L, sizeof(queue));
  q->head = 1;
  q->tail = 0;
  lua_pushvalue(L, LUA_ENVIRONINDEX);
  lua_setmetatable(L, -2);
  lua_newtable(L);
  lua_setfenv(L, -2);
  return 1;
}

static int queue_insert (lua_State *L) {
  queue *q = checkqueue(L, 1);
  lua_settop(L, 2); /* queue, element */
  if (lua_isnil(L, 2)) return 0;
  lua_getfenv(L, 1);
  lua_pushvalue(L, 2);
  lua_rawseti(L, -2, ++(q->tail));
  return 0;
}

static int queue_retrieve (lua_State *L) {
  return retrieve(L, checkqueue(L, 1), lua_toboolean(L, 2));
}

static int queue_front (lua_State *L) {
  return retrieve(L, checkqueue(L, 1), 1);
}

static int queue_isempty (lua_State *L) {
  queue *q = checkqueue(L, 1);
  lua_pushboolean(L, len(q) == 0);
  return 1;
}


static int queue_len (lua_State *L) {
  queue *q = (queue *) lua_touserdata(L, 1);
  lua_pushinteger(L, len(q));
  return 1;
}

static int queue_tostring (lua_State *L) {
  lua_pushfstring(L, "queue: %p", lua_touserdata(L, 1));
  return 1;
}


static const luaL_reg queue_func[] = {
  {"insert", queue_insert},
  {"into", queue_insert}, /* alias */
  {"retrieve", queue_retrieve},
  {"front", queue_front},
  {"isempty", queue_isempty},
  {NULL, NULL}
};

int luaopen_queue (lua_State *L) {
  lua_newtable(L); /* class */
  lua_newtable(L); /* new environment */
  lua_pushvalue(L, -1);
  lua_replace(L, LUA_ENVIRONINDEX);
  lua_pushcfunction(L, queue_tostring);
  lua_setfield(L, -2, "__tostring");
  lua_pushcfunction(L, queue_len);
  lua_setfield(L, -2, "__len");
  lua_pushvalue(L, -2);
  lua_setfield(L, -2, "__index");
  lua_pop(L, 1); /* env/metatable */
  luaL_register(L, NULL, queue_func);
  lua_pushcfunction(L, queue_new);
  return 1; /* new queue */
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
