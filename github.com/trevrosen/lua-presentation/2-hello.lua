-- Take a Twitter handle interactively, grab the feed
-- and optionally dump the raw HTML to the console.

local io   = require('io')          -- from the stdlib
local http = require('socket.http') -- from LuaSocket library installed via luarocks

print("Whose Twitter feed do you want to retrieve?")
local username = io.read() -- read from stdin like Ruby's "gets"

local url = "http://twitter.com/"..username
print(string.format("Sending request to %s",url))

local response = http.request(url) -- make the GET request

print("Got it.  Do you want to print it to the console?")

local pref = io.read()

if string.match(pref, '[Yy]') ~= nil then
  print(response)
else
  print("OK then, be that way.")
end

