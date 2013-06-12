local M = {}

M.init =  function(conf)
	local sched = require 'sched'
	local toribio = require 'toribio' 

	local mice = toribio.wait_for_device({module='mice'})
	mice.reset_pos(0,0)
	
	local haar = toribio.wait_for_device('haar')
	print ('HAAR FOUND', haar.name)
	
	local dynamixelbus = toribio.wait_for_device({module='dynamixel'})
	local bcaster = dynamixelbus.get_broadcaster()
	local motor_pan = toribio.wait_for_device(conf.motor_pan)
	print ('PAN FOUND', motor_pan.name)

	local motor_tilt = toribio.wait_for_device(conf.motor_tilt)
	print ('TILT FOUND', motor_tilt.name)
	
	bcaster.set.torque_enable(true)
	
	---[[
	sched.run(function()
		while true do
			bcaster.set.led(true)
			sched.sleep(1)
			bcaster.set.led(false)
			sched.sleep(1)
		end
	end)
	--]]
	
	---[[
	local last_pan, last_tilt = 150, 150
	motor_pan.rotate_to_angle (last_pan, 60)
	motor_tilt.rotate_to_angle (last_tilt, 60)
	--]]
	
	--[[
	sched.run(function()
		--sched.sleep(5)
		--local i = 0
		while true do
			--i=i+1
			--if i==1000 then print ('tick'); i=0 end
			--assert(motor_pan.get_position())
			sched.yield()
		end
	end)
	--]]
	
	---[[
	local mouse_tracking = false
	toribio.register_callback(mice, 'move', function(x,y)
		if mouse_tracking==true then 
			motor_pan.rotate_to_angle (last_pan+x/5)
			motor_tilt.rotate_to_angle (last_tilt+y/5)
		end
	end)

	toribio.register_callback(mice, 'leftbutton', function(pressed)
		if pressed==true then 
			mice.reset_pos(0,0)
			last_pan = motor_pan.get.present_position()
			last_tilt = motor_tilt.get.present_position()
			assert(last_pan, last_tilt )
			mouse_tracking = true
		else
			mouse_tracking = false
		end
	end)

	toribio.register_callback(haar, 'match', function(x, y, sx, sz)
		if not mouse_tracking then
			print('haar match:',x, y, sx, sz)
			local dx, dy= x-80, 80-y
			print (dx, dy)
			motor_pan.rotate_to_angle (motor_pan.get.present_position()+dx/5)
			motor_tilt.rotate_to_angle (motor_tilt.get.present_position()+dy/5)
		end
	end)
	--]]
end

return M
