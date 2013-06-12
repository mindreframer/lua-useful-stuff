require"luma"

local files = {
	"aut.lua",
	"exception.lua",
	"inc.lua",
	"mat.lua",
	"nor.lua",
	"power.lua",
	"use.lua"
}

for _, file in ipairs(files) do
  luma.dofile(file)
end
