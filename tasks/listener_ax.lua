local M = {}

M.init =  function(conf)
	local sched = require 'sched'
	local toribio = require 'toribio' 

	return sched.run(function()
		local dynamixelbus = toribio.wait_for_device(conf.devicename or 'dynamixel:/dev/ttyUSB0')
		local bcaster = dynamixelbus.get_broadcaster()
		local m3 = toribio.wait_for_device('ax12:3')
		local m12 = toribio.wait_for_device('ax12:12')
		--print ('torqueenable:', bcaster.set_torque_enable(false))
		--sched.sleep(3)

		---[[
		sched.run(function()
			while true do
				print(m3.get.id())
				sched.sleep(0.1)
			end
		end)
		--]]
		---[[
		sched.run(function()
			while true do
				print('', m12.get.id())
				sched.sleep(0.1)
			end
		end)
		--]]
		
		--[[
		while true do
			--bcaster.set_led(true)
			--sched.sleep(0.1)
			--bcaster.set_led(false)
			--sched.sleep(0.1)
			--print('pinging...')
			--print (m3.get_position())
			dynamixelbus.reg_write_start()
			m3.set_led(true)
			sched.sleep(1)
			m12.set_led(true)
			sched.sleep(1)
			dynamixelbus.reg_write_action()
			sched.sleep(1)
			bcaster.set_led(false)
		end
		--]]
	end)
end

return M
