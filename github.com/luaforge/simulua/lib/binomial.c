/*
 * Binomial heaps (with a few twists)
 * Check license at the bottom of the file
 * $Id: binomial.c,v 1.1 2008-08-19 23:36:45 carvalho Exp $
*/

#include <lua.h>
#include <lauxlib.h>

typedef struct nodestc *nodeptr;
typedef struct nodestc {
  lua_Number key;
  nodeptr parent;
  nodeptr child;
  nodeptr sibling;
  int degree;
} node;

typedef struct heapstc {
  nodeptr head;
  nodeptr min;
} heap;


static void resetnode (node *n, lua_Number k) {
  n->key = k;
  n->parent = NULL;
  n->child = NULL;
  n->sibling = NULL;
  n->degree = 0;
}

/* assumes record is at top of stack and heap is at pos */
static node *newnode (lua_State *L, lua_Number k, int pos) {
  node *n = (node *) lua_newuserdata(L, sizeof(node));
  resetnode(n, k);
  lua_getfenv(L, pos);
  lua_pushlightuserdata(L, (void *) n);
  lua_pushvalue(L, -3); /* x */
  lua_rawset(L, -3); /* env[light(x)] = x */
  if (!lua_isnil(L, -4)) { /* record? */
    lua_pushvalue(L, -2); /* x */
    lua_pushvalue(L, -4); /* record */
    lua_rawset(L, -3); /* env[x] = record */
  }
  lua_pop(L, 3); /* env, x, record */
  return n;
}

/* assumes env is at top of stack */
static void delnode (lua_State *L, node *n) {
  lua_pushlightuserdata(L, (void *) n);
  lua_pushvalue(L, -1);
  lua_rawget(L, -3); /* n */
  lua_pushnil(L);
  lua_rawset(L, -4); /* env[n] = nil */
  lua_pushnil(L);
  lua_rawset(L, -3); /* env[light(n)] = nil */
}

static heap *checkheap (lua_State *L, int pos) {
  heap *h = NULL;
  if (lua_isnoneornil(L, pos) || !lua_getmetatable(L, pos)) return NULL;
  if (lua_rawequal(L, -1, LUA_ENVIRONINDEX))
    h = (heap *) lua_touserdata(L, pos);
  lua_pop(L, 1); /* MT */
  return h;
}

static void pushkeyrecord (lua_State *L, node *n, int pos) {
  if (n == NULL) {
    lua_pushnil(L); lua_pushnil(L); return;
  }
  lua_pushnumber(L, n->key);
  lua_getfenv(L, pos);
  lua_pushlightuserdata(L, (void *) n);
  lua_rawget(L, -2); /* n */
  lua_rawget(L, -2); /* record */
  lua_replace(L, -2);
}

static void updatemin (heap *h) {
  lua_Number min;
  node *x = h->head;
  h->min = x;
  if (x != NULL) min = x->key;
  while (x != NULL) {
    if (x->key < min) {
      min = x->key; h->min = x;
    }
    x = x->sibling;
  }
}

static void link (node *y, node *z) {
  y->parent = z;
  y->sibling = z->child;
  z->child = y;
  z->degree++;
}

/* heap and root list */
static void merge (heap *h, node *l) {
  node *x = h->head;
  node *y = l;
  node *p = NULL; /* prev-x */
  node *t; /* temp */
  if (x == NULL) h->head = y;
  else if (y != NULL) {
    h->head = (x->degree >= y->degree) ? y : x;
    /* merge */
    while (x != NULL && y != NULL) {
      if (x->degree >= y->degree) { /* insert y? */
        t = y->sibling;
        y->sibling = x;
        if (p != NULL) p->sibling = y;
        p = y;
        y = t;
      }
      else {
        p = x;
        x = x->sibling;
      }
    }
    if (x == NULL) p->sibling = y;
  }
}

static void unite (heap *h, node *l, int after) {
  node *prevx, *x, *nextx;
  merge(h, l);
  if (h->head == NULL) return;
  prevx = NULL;
  x = h->head;
  nextx = x->sibling;
  while (nextx != NULL) {
    if ((x->degree != nextx->degree) || (nextx->sibling != NULL
          && nextx->sibling->degree == x->degree)) {
      prevx = x; x = nextx;
    }
    else if (x->key < nextx->key || (!after && x->key == nextx->key)) {
      x->sibling = nextx->sibling; link(nextx, x);
    }
    else {
      if (prevx == NULL) h->head = nextx;
      else prevx->sibling = nextx;
      link(x, nextx);
      x = nextx;
    }
    nextx = x->sibling;
  }
}

static node *extract (heap *h, node *x) {
  node *y = h->head;
  node *p = NULL; /* prev-y */
  node *n; /* next-y */
  if (x == NULL) return NULL;
  /* find x in root list */
  while (y != x && y != NULL) {
    p = y; y = y->sibling;
  }
  if (y == NULL) return NULL; /* x not in root list */
  /* remove x from root list */
  if (p == NULL) /* first node? */
    h->head = x->sibling;
  else
    p->sibling = x->sibling;
  x->sibling = NULL;
  /* reverse order in child list of x */
  p = NULL; y = x->child;
  if (y != NULL) {
    n = y->sibling;
    while (y != NULL) {
      y->parent = NULL;
      y->sibling = p;
      p = y;
      y = n;
      if (y != NULL) n = y->sibling;
    }
  }
  unite(h, p, 0); /* with priority */
  if (h->min == x) updatemin(h);
  return x;
}

/* heap env at top, record at pos */
static node *find (lua_State *L, int pos) {
  node *x = NULL;
  lua_pushnil(L);
  while (lua_next(L, -2)) {
    if (lua_type(L, -2) == LUA_TUSERDATA && lua_equal(L, -1, pos))
      x = (node *) lua_touserdata(L, -2);
    lua_pop(L, 1);
  }
  return x;
}

/* assumes env is at top of stack */
static void swap (lua_State *L, node *x, node *y) {
  lua_Number k;
  /* exchange keys */
  k = x->key; x->key = y->key; y->key = k;
  /* exchange records */
  lua_pushlightuserdata(L, (void *) x);
  lua_rawget(L, -2); /* x */
  lua_pushvalue(L, -1);
  lua_rawget(L, -3); /* record[x] */
  lua_pushlightuserdata(L, (void *) y);
  lua_rawget(L, -4); /* y */
  lua_pushvalue(L, -1);
  lua_rawget(L, -5); /* record[y] */
  lua_insert(L, -3);
  lua_insert(L, -2);
  lua_rawset(L, -5);
  lua_rawset(L, -3);
}

/* assumes env is at top of stack */
static node *delete (lua_State *L, heap *h, node *x) {
  node *y = x;
  node *z = y->parent;
  while (z != NULL) {
    swap(L, y, z);
    y = z; z = y->parent;
  }
  return extract(h, y);
}

/* assume env is at top of stack */
static node *decreasekey (lua_State *L, node *x, lua_Number k, int after) {
  node *y = x;
  node *z = y->parent;
  x->key = k;
  while (z != NULL && (y->key < z->key
        || (!after && y->key == z->key))) { /* priority? */
    swap(L, y, z);
    y = z; z = y->parent;
  }
  return y;
}


/* =======   methods   ======= */

static int heap_new (lua_State *L) {
  heap *h = lua_newuserdata(L, sizeof(heap));
  h->head = NULL;
  h->min = NULL;
  lua_pushvalue(L, LUA_ENVIRONINDEX);
  lua_setmetatable(L, -2);
  lua_newtable(L);
  lua_setfenv(L, -2);
  return 1;
}

static int heap_isempty (lua_State *L) {
  heap *h = checkheap(L, 1);
  lua_pushboolean(L, h->head == NULL);
  return 1;
}

static int heap_min (lua_State *L) {
  heap *h = checkheap(L, 1);
  node *n = h->min;
  pushkeyrecord(L, n, 1);
  return 2;
}

static int heap_get (lua_State *L) {
  node *x;
  checkheap(L, 1);
  lua_settop(L, 2); /* heap, record */
  if (lua_isnil(L, 2)) return 1;
  lua_getfenv(L, 1);
  x = find(L, 2);
  if (x != NULL) lua_pushnumber(L, x->key); /* found */
  else lua_pushnil(L);
  return 1;
}

static int heap_insert (lua_State *L) {
  heap *h = checkheap(L, 1);
  lua_Number k = luaL_checknumber(L, 2);
  int after = lua_toboolean(L, 4);
  node *x;
  lua_settop(L, 3); /* heap, key [, record] */
  x = newnode(L, k, 1);
  unite(h, x, after);
  if (h->min == NULL
      || h->min->key > x->key
      || (!after && h->min->key == x->key)) /* priority? */
    h->min = x;
  lua_pop(L, 1); /* key */
  return 1;
}

static int heap_retrieve (lua_State *L) { /* extract-min */ 
  heap *h = checkheap(L, 1);
  node *x = extract(h, h->min);
  pushkeyrecord(L, x, 1);
  if (x != NULL) {
    lua_getfenv(L, 1);
    delnode(L, x);
    lua_pop(L, 1); /* env */
  }
  return 2;
}

static int heap_remove (lua_State *L) {
  heap *h = checkheap(L, 1);
  node *x = NULL;
  int removed = 0;
  lua_settop(L, 2); /* heap, record */
  if (!lua_isnil(L, 2)) {
    /* find node */
    lua_getfenv(L, 1);
    x = find(L, 2);
    if (x != NULL) { /* found? */
      x = delete(L, h, x);
      delnode(L, x);
      removed = 1;
    }
  }
  lua_pushboolean(L, removed);
  return 1;
}

static int heap_change (lua_State *L) {
  heap *h = checkheap(L, 1);
  node *x = NULL;
  lua_Number k = luaL_checknumber(L, 3);
  int after = lua_toboolean(L, 4);
  int changed = 0;
  lua_settop(L, 2); /* heap, record */
  if (lua_isnil(L, 2)) luaL_error(L, "record not specified");
  /* find node */
  lua_getfenv(L, 1);
  x = find(L, 2);
  if (x != NULL && x->key != k) { /* found and need change? */
    if (x->key > k) {
      x = decreasekey(L, x, k, after);
      if (h->min->key > x->key
          || (!after && h->min->key == x->key)) /* priority? */
        h->min = x;
    }
    else { /* x->key < k */
      x = delete(L, h, x);
      resetnode(x, k);
      unite(h, x, after); /* re-insert */
      if (h->min == NULL || h->min->key > x->key
          || (!after && h->min->key == x->key)) /* priority? */
        h->min = x;
    }
    changed = 1;
  }
  lua_pushboolean(L, changed);
  return 1;
}


/* __tostring */
static int heap_tostring (lua_State *L) {
  lua_pushfstring(L, "heap: %p", lua_touserdata(L, 1));
  return 1;
}

static const luaL_reg binomial_func[] = {
  {"isempty", heap_isempty},
  {"get", heap_get},
  {"min", heap_min},
  {"insert", heap_insert},
  {"into", heap_insert}, /* alias */
  {"retrieve", heap_retrieve},
  {"remove", heap_remove},
  {"change", heap_change},
  {NULL, NULL}
};

int luaopen_binomial (lua_State *L) {
  lua_newtable(L); /* class */
  lua_newtable(L); /* new environment */
  lua_pushvalue(L, -1);
  lua_replace(L, LUA_ENVIRONINDEX);
  lua_pushcfunction(L, heap_tostring);
  lua_setfield(L, -2, "__tostring");
  lua_pushvalue(L, -2);
  lua_setfield(L, -2, "__index");
  lua_pop(L, 1); /* env/metatable */
  luaL_register(L, NULL, binomial_func);
  lua_pushcfunction(L, heap_new);
  return 1; /* new heap */
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
