local M = {}
local toribio = require 'toribio'
local sched = require 'sched'

M.init = function(conf)

	sched.run(function()
		--initialize motors
		local motor_left = toribio.wait_for_device(conf.motor_left)
		local motor_right = toribio.wait_for_device(conf.motor_right)
		motor_left.init_mode_wheel()
		motor_right.init_mode_wheel()

		--initialize socket
		local selector = require "tasks/selector"
		local udp = selector.new_udp(nil, nil, conf.ip, conf.port, -1)

		--listen for messages
		sched.sigrun({emitter=selector.task, events={udp.events.data}}, function(_, _, msg) 
			local left, right
			if msg then
				left, right = msg:match('^([^,]+),([^,]+)$')
				print("!U", left, right) 
			else
				left, right = 0, 0
			end
			motor_left.set_speed(left)
			motor_right.set_speed(right)
			return true
		end)
	end)
end

return M
