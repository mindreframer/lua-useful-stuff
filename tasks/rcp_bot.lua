local M = {}
local toribio = require 'toribio'
local sched = require 'sched'
local proxy = require 'tasks/proxy'

M.init = function(conf)

	sched.run(function()
		--initialize motors
		--[[
		local motor_left = toribio.wait_for_device(conf.motor_left)
		local motor_right = toribio.wait_for_device(conf.motor_right)
		motor_left.init_mode_wheel()
		motor_right.init_mode_wheel()
		--]]
		
		local waitd = proxy.new_remote_waitd('127.0.0.1', 1985, {
			emitter = {'mice:/dev/input/mice'},
			events = {'move', 'leftbutton'},
			--timeout = 1,
		})
		
		--listen for messages
		local left, right = 0, 0
		sched.sigrun(waitd, function(emitter, arrived, _, event, v1, v2) 
			--print (emitter, arrived, event, v1, v2)
			if not emitter or (event=='leftbutton' and v1=='true') then 
				left, right = 0, 0
			else
				local x, y = tonumber(v1), tonumber(v2) 
				if x and y then 
					left, right  = (y + x)/2, (y - x)/2
				end
			end
			print (left, right)
			--[[
			motor_left.set_speed(left)
			motor_right.set_speed(right)
			--]]
		end)
	end)
end

return M
