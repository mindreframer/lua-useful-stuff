local M = {}

M.init = function(conf)
	local sched = require 'sched'
	
	return sched.run(function()
		local toribio = require 'toribio'
		local mice = toribio.wait_for_device({module='mice'})
		
		---[[
		toribio.register_callback(mice, 'leftbutton', function(v)
			print('left!',v)
		end)
		toribio.register_callback(mice, 'rightbutton', function(v)
			print('right!',v)
		end)
		toribio.register_callback(mice, 'middlebutton', function(v)
			print('middle!',v)
		end)
		--]]

		--[[
		local waitd = {
			emitter=mice.task, 
			timeout=conf.timeout or 1, 
			events={mice.events.leftbutton, mice.events.rightbutton, mice.events.middlebutton}
		}
		while true do
			local emitter, ev, v = sched.wait(waitd)
			if emitter then 
				--print('mice:', ev, v) 
			else
				print(mice.get_pos())
			end
		end
		--]]
	end)
end

return M
