local M = {}

local toribio = require 'toribio'

M.init = function()
	local sched = require 'sched'
	
	return sched.run(function(conf)
		local xo_accel = toribio.wait_for_device('xo_accel')
		while true do
			print (xo_accel.get_accel())
			sched.sleep(conf.interval or 0.5)
		end
	end)
end

return M
