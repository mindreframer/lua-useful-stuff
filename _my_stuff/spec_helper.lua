local assert = require("luassert")
local say    = require("say") --our i18n lib, installed through luarocks, included as a luassert dependency

local function has_property(state, arguments)
  local property = arguments[1]
  local table = arguments[2]
  for key, value in pairs(table) do
    if key == property then
      return true
    end
  end
  return false
end


say:set_namespace("en")
say:set("assertion.has_property.positive", "Expected property %s in:\n%s")
say:set("assertion.has_property.negative", "Expected property %s to not be in:\n%s")
assert:register("assertion", "has_property", has_property, "assertion.has_property.positive", "assertion.has_property.negative")

-- function(a, b) return (tostring(b)):match(a) end)

local function matches(state, arguments)
  local regex = arguments[1]
  local string = arguments[2]
  local res = (tostring(string)):match(regex)
  return not(not res)
end


say:set_namespace("en")
say:set("assertion.matches.positive", "Expected  %s to match:\n%s")
say:set("assertion.matches.negative", "Expected %s to not match:\n%s")
assert:register("assertion", "matches", matches, "assertion.matches.positive", "assertion.matches.negative")


