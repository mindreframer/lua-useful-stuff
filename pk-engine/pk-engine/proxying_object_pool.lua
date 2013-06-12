--------------------------------------------------------------------------------
-- proxying_object_pool: pool of simple objects
-- This file is a part of pk-engine library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------

local arguments,
      optional_arguments,
      method_arguments
      = import 'lua-nucleo/args.lua'
      {
        'arguments',
        'optional_arguments',
        'method_arguments'
      }

local unique_object
      = import 'lua-nucleo/misc.lua'
      {
        'unique_object'
      }

local is_table,
      is_userdata,
      is_function
      = import 'lua-nucleo/type.lua'
      {
        'is_table',
        'is_userdata',
        'is_function'
      }

--------------------------------------------------------------------------------

-- TODO: Generalize to lua-nucleo
-- TODO: Hack! Refactor this!
-- Note: Hides all object metatable's advanced stuff like operators
local make_proxying_object_pool
do
  local proxy_newindex = function(t, k, v)
    -- NOTE: This restriction may be lifted if needed,
    --       but think well before doing that.
    error("attempted to write to proxy object at index `"..tostring(k).."'")
  end

  local PROXY_TAG = unique_object()

  local wrap_method = function(proxy, object, key)
    return function(a1, ...)
      if a1 == proxy then -- Colon call
        return object[key](object, ...)
      end

      return object[key](a1, ...) -- Dot call
    end
  end

  local method_index = function(t, k)
    local mt = debug.getmetatable(t)
    assert(mt.tag_ == PROXY_TAG, "bad object type")
    assert(mt.is_active_ == true, "attempted to use inactive proxy")

    return mt.method_cache_[k]
  end

  local make_method_cache_mt
  do
    make_method_cache_mt = function(proxy, object)
      return
      {
        __index = function(t, k)
          local v = object[k]
          --print("METHOD_CACHE", k, type(v), v)
          if is_function(v) then -- Note: this check can't be cached to allow memoization.
            v = wrap_method(proxy, object, k)
            t[k] = v
          end
          -- Note: Can't cache non-methods
          return v
        end;
      }
    end
  end

  local deactivate_proxy = function(proxy)
    local mt = debug.getmetatable(proxy)
    assert(mt.tag_ == PROXY_TAG, "bad object type")
    assert(mt.is_active_ == true, "attempted to deactivate inactive proxy")
    mt.is_active_ = false
  end

  local make_proxy = function(object, pool)
    -- HACK: Need userdata to call __gc
    --print("creating proxy for object", object)
    local proxy = newproxy()
    assert(
        debug.setmetatable(
            proxy,
            {
              __index = method_index;
              __newindex = proxy_newindex;

              __tostring = function()
                -- NOTE: Adding fixed prefix to ease debugging.
                return "PROXY: " .. tostring(object)
              end;

              -- TODO: Want to set __metatable = true. Fix or remove proxy_newindex.
              __gc = function(proxy)
                local mt = debug.getmetatable(proxy)
                if mt.is_active_ then
                  --print("releasing object to free objects pool", object)
                  pool[#pool + 1] = object
                else
                  --print("proxied object was disowned, not returning to pool", object)
                end
              end;
              --
              tag_ = PROXY_TAG;
              method_cache_ = setmetatable({}, make_method_cache_mt(proxy, object));
              is_active_ = true;
            }
          )
      )
    return proxy
  end

  local acquire = function(self)
    method_arguments(
        self
      )

    local free_objects = self.free_objects_

    local object = table.remove(free_objects)
    if object ~= nil then
      local proxy = make_proxy(object, free_objects)
      self.proxy_to_object_[proxy] = object
      return proxy
    end

    return nil
  end

  local unacquire = function(self, proxy)
    method_arguments(
        self,
        "userdata", proxy
      )

    local object = assert(
        self.proxy_to_object_[proxy],
        "can't unacquire unknown proxy"
      )
    deactivate_proxy(proxy)

    local free_objects = self.free_objects_
    free_objects[#free_objects + 1] = object
  end

  -- Object ownership is transferred to the pool
  local own = function(self, object)
    method_arguments(
        self
      )

    -- TODO: Need object metatype in arguments
    if not (is_table(object) or is_userdata(object)) then
      error("own: wrong object type: " .. type(object))
    end

    local free_objects = self.free_objects_
    free_objects[#free_objects + 1] = object

    assert(self.all_objects_[object] == nil, "attempted to own same object twice")
    self.all_objects_[object] = true -- Need this to prevent object collection
  end

  -- You must not use proxy after you've called this function
  local disown = function(self, proxy)
    method_arguments(
        self,
        "userdata", proxy
      )

    local object = assert(self.proxy_to_object_[proxy], "can't disown unknown proxy")
    deactivate_proxy(proxy)

    self.all_objects_[object] = nil

    -- Note: self.free_objects_ can't contain object if it has proxy.

    return object
  end

  local proxy_to_object_mt = { __mode = "k" } -- TODO: kv?!

  make_proxying_object_pool = function()

    return
    {
      acquire = acquire;
      unacquire = unacquire;
      own = own;
      disown = disown;
      --
      proxy_to_object_ = setmetatable({ }, proxy_to_object_mt);
      free_objects_ = { };
      all_objects_ = { };
    }
  end
end

return
{
  make_proxying_object_pool = make_proxying_object_pool;
}
