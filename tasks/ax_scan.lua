local M = {}

M.init = function(conf)
	local sched = require 'sched'
	local toribio = require 'toribio' 

	sched.run(function()
		local motor = toribio.wait_for_device(conf.motor)
		motor.init_mode_joint()
		motor.set_speed(conf.speed)

		while true do
		
			motor.set_position(conf.min)
			repeat
				sched.sleep(0.5)
			until not motor.is_moving()
			
			motor.set_position(conf.max)
			repeat
				sched.sleep(0.5)
			until not motor.is_moving()
		
		end
	end)
end

return M