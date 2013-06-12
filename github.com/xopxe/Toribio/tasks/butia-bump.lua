local M = {}

M.init = function()
	local sched = require 'sched'
	
	return sched.run(function()
		local toribio = require 'toribio'
		
		local motors=toribio.wait_for_devices('bb-motors')
		local distanc = toribio.wait_for_device('bb-distanc:0')
		
		sched.run(function()
			while true do
				local dist = distanc.getValue()
				if dist < 100 then
					sched.signal('avoid!')
				end
				sched.sleep(0.1)
			end
		end)
		
		sched.run(function()
			while true do
				sched.sleep(5+5*math.random())
				sched.signal('avoid!')
			end
		end)
		
		sched.sigrun(
			{emitter='*', events={'avoid!'}}, 
			function()
				motors.setvel2mtr(0, 500, 0, 500)
				sched.sleep(1)
				motors.setvel2mtr(0, 500, 1, 500)
				sched.sleep(1+2*math.random())
				motors.setvel2mtr(1, 500, 1, 500)
			end
		)
		
		--motors.setvel2mtr(1, 500, 1, 500)
	end)
end

return M
