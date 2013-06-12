module("accelerator", package.seeall)
local json = require("cjson")
local memcached = require("resty.memcached")
local debug
debug = function(kind, msg)
  if msg then
    msg = kind .. ": " .. msg
  else
    msg = kind
  end
  return ngx.log(ngx.DEBUG, msg)
end
local memclient
memclient = function(opts)
  if opts == nil then
    opts = { }
  end
  local client, err = memcached:new()
  if not client or err then
    error(err or "problem creating client")
  end
  client:set_timeout(1000)
  local ok
  ok, err = client:connect((opts.host or "127.0.0.1"), (opts.port or 11211))
  if not ok or err then
    error(err or "problem connecting")
  end
  return client
end
local access
access = function(opts)
  if ngx.var.request_method ~= "GET" then
    return 
  end
  if ngx.is_subrequest then
    return 
  end
  local fn
  fn = function()
    local memc = memclient(opts)
    local key = ngx.var.uri
    if ngx.var.args then
      key = key .. ('?' .. ngx.var.args)
    end
    local cache, flags, err = memc:get(key)
    if err then
      error(err)
    end
    if cache then
      debug("read cache", cache)
      cache = json.decode(cache)
      ngx.header['X-Server'] = 'nginx-accelerator'
      if cache.header then
        for k, v in pairs(cache.header) do
          ngx.header[k] = v
        end
      end
      local expired = os.time() - cache.time >= cache.ttl
      ngx.header['X-Cache'] = 'HIT'
      if expired then
        ngx.header['X-Cache-State'] = 'EXPIRED'
      else
        ngx.header['X-Cache-State'] = cache.ttl - (os.time() - cache.time)
      end
      if cache.body then
        ngx.say(cache.body)
      end
    end
    if not cache or os.time() - cache.time >= cache.ttl then
      local co = coroutine.create(function()
        cache = cache or { }
        cache.time = os.time()
        memc:set(key, json.encode(cache))
        local res = ngx.location.capture(key)
        if not res then
          return 
        end
        local ttl = nil
        do
          local cc = res.header["Cache-Control"]
          if cc then
            res.header["Cache-Control"] = nil
            local x
            x, x, ttl = string.find(cc, "max%-age=(%d+)")
          end
        end
        if ttl then
          ttl = tonumber(ttl)
          debug("ttl", ttl)
        end
        res.time = os.time()
        res.ttl = ttl or opts.ttl or 10
        memc:set(key, json.encode(res))
        return debug("write cache")
      end)
      coroutine.resume(co)
    end
    if cache and cache.body then
      return ngx.exit(ngx.HTTP_OK)
    end
  end
  local status, err = pcall(fn)
  if err then
    return ngx.log(ngx.ERR, err)
  end
end
return {
  access = access
}
