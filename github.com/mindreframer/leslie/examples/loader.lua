require "leslie"

local t = leslie.loader('template.txt')
local c = leslie.Context({
  name = "Leslie",
  version = leslie.version
})

print(t:render(c))
