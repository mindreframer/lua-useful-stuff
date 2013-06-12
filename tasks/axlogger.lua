local M = {}
local sched=require 'sched'
local toribio = require 'toribio'
M.init = function(conf)
	sched.run(function()
		local file = io.open(conf.outfile or 'data.log', 'w')
		local motor = toribio.wait_for_device(conf.motorname)
		while true do
			local l = motor:get_load()
			print(l)
			file:write(l..'\n')
			file:flush()
			sched.sleep(conf.interval or 5)
		end
	end)
end

return M