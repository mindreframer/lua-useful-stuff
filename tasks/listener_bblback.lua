local M = {}

M.init = function()
	local sched = require 'sched'
	
	return sched.run(function()
		local toribio = require 'toribio'
		local lback = assert(toribio.wait_for_device('bb-lback'))
		
		while true do
			print(lback.send(sched.get_time()))
			--sched.sleep(5)
			--print(lback.read())
			sched.sleep(1)
			sched.yield()
		end
	end)
end

return M
