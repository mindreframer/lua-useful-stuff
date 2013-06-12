require 'rubygems'
require 'cgi'
require 'json'
require 'memcached'

class Accelerator

  def initialize(host="localhost:11211")
    @memc = Memcached.new(host)
  end

  def delete(uri)
    @memc.delete(key(uri))
  end

  def expire(uri, ttl=nil)
    if data = get_and_set_time(uri)
      data[:ttl]   = ttl if ttl
      data[:time] -= data[:ttl]
      @memc.set(key(uri), data.to_json, 604800, false)
    end
  end

  def get(uri)
    if data = get_and_parse(uri)
      [ data.delete(:body), data ]
    end
  end

  def set(uri, body, ttl=nil)
    data   = get_and_set_time(uri)
    data ||= { :time => Time.now.to_i, :ttl => ttl || 10 }
    data[:body] = body
    @memc.set(key(uri), data.to_json, 604800, false)
  end

  private

  def key(k)
    CGI.escape(k).gsub(/%../) { |s| s.downcase }
  end

  def get_and_parse(uri)
    data = @memc.get(key(uri), nil) rescue nil
    if data
      JSON.parse(data, :symbolize_names => true)
    end
  end

  def get_and_set_time(uri)
    if data = get_and_parse(uri)
      data[:time] = Time.now.to_i
    end
    data
  end
end