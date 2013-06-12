local M = {}

M.init = function()
	local sched = require 'sched'
	
	return sched.run(function()
		local toribio = require 'toribio'
		local haar = toribio.wait_for_device('haar')
		print ('listener haar found:', haar)
		
		--[[
		local waitd = {
			emitter=mice.task, 
			timeout=conf.timeout or 1, 
			events={'leftbutton', 'rightbutton', 'middlebutton'}
		}
		while true do
			local emitter, ev, v = sched.wait(waitd)
			if emitter then 
				print('mice:', ev, v) 
			else
				print(mice.get_pos.call())
			end
		end
		--]]
		
		---[[
		toribio.register_callback(haar, 'match', function(x, y, sx, sz)
			print('haar match:',x, y, sx, sz)
			--gpsd.set_watch(true)
		end)
		--]]
	end)
end

return M