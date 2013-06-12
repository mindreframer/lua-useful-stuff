module "accelerator", package.seeall


-- Dependencies

json      = require "cjson"
memcached = require "resty.memcached"


-- Debug log

debug = (kind, msg) ->
  msg = if msg then kind .. ": " .. msg else kind
  ngx.log(ngx.DEBUG, msg)


-- Create memcached client

memclient = (opts={}) ->
  client, err = memcached\new()
  error(err or "problem creating client") if not client or err

  -- Set memcached connection timeout to 1 sec
  client\set_timeout(1000)

  -- Connect to memcached server
  ok, err = client\connect((opts.host or "127.0.0.1"), (opts.port or 11211))
  error(err or "problem connecting") if not ok or err

  client


-- Execute within access_by_lua:
-- http://wiki.nginx.org/HttpLuaModule#access_by_lua

access = (opts) ->
  return if ngx.var.request_method ~= "GET"
  return if ngx.is_subrequest

  fn = ->
    memc = memclient(opts)

    key = ngx.var.uri
    if ngx.var.args
      key ..= '?' .. ngx.var.args
    cache, flags, err = memc\get(key)
    error(err) if err

    if cache
      debug("read cache", cache)
      cache = json.decode(cache)
      
      ngx.header['X-Server'] = 'nginx-accelerator'
      if cache.header
        for k,v in pairs cache.header
          ngx.header[k] = v

      expired = os.time() - cache.time >= cache.ttl
      ngx.header['X-Cache'] = 'HIT'
      if expired
        ngx.header['X-Cache-State'] = 'EXPIRED'
      else
        ngx.header['X-Cache-State'] = cache.ttl - (os.time() - cache.time)

      if cache.body
        ngx.say(cache.body) -- render body

    -- Rewrite cache if cache does not exist or ttl has expired
    if not cache or os.time() - cache.time >= cache.ttl
      co = coroutine.create ->

        -- Immediately update the time to prevent multiple writes race condition
        cache = cache or {}
        cache.time = os.time()
        memc\set(key, json.encode(cache))

        -- Make subrequest to the proxy server
        res = ngx.location.capture(key)
        return if not res

        -- Parse TTL
        ttl = nil
        if cc = res.header["Cache-Control"]
          res.header["Cache-Control"] = nil
          x, x, ttl = string.find(cc, "max%-age=(%d+)")

        if ttl
          ttl = tonumber(ttl)
          debug("ttl", ttl)

        res.time = os.time()
        res.ttl  = ttl or opts.ttl or 10

        -- Write through cache, never set a ttl
        memc\set(key, json.encode(res))
        debug("write cache")

      coroutine.resume(co)

    -- Prevent further phases from executing if body rendered
    if cache and cache.body
      ngx.exit(ngx.HTTP_OK)

  status, err = pcall(fn)
  ngx.log(ngx.ERR, err) if err


-- Return

return { access: access }