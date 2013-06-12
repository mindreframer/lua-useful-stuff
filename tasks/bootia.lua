local M = {}

local sched = require 'sched'
local toribio = require 'toribio'

M.init = function()
	sched.run(function()
		local button =  toribio.wait_for_device({module='bb-button'})
		print ('BUTTON FOUND', button.name)
		local pressed = false
		while true do
			local now = ( button.getValue()==0 )
			if pressed and not now then 
				print ('change direction!')
				sched.signal('change direction!')
				pressed=now
			elseif not pressed and now then
				pressed=now
			end
			sched.sleep(0.1)
		end
	end)
	
	sched.run(function()
		local motors = toribio.wait_for_device('bb-motors')
		print ('MOTORS FOUND', motors.name, motors.getVersion())
		motors.testMotors()
		local direction = 1
		sched.sigrun({emitter='*', events={'change direction!'}}, function()
			motors.setvel2mtr(direction, 200, direction, 200)
			print ('OPA', direction)
			direction=1-direction
		end)
	end)
	
	--[[
	sched.run(function()
		while true do
			sched.sleep(10 + 10*math.random())
			sched.signal('change direction!')
		end
	end)
	--]]
end

return M
