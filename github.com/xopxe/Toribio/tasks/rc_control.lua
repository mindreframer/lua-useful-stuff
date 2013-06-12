local M = {}
local toribio = require 'toribio'
local sched = require 'sched'

M.init = function(conf)

	local nixio = require 'nixio'
	local udp = assert(nixio.bind('*', 0, 'inet', 'dgram'))
	udp:connect(conf.ip, conf.port)
	local function generate_output (x, y)
		local left = (y + x)/2
		local right = (y - x)/2
		local msg = left..','..right
		udp:send(msg)
	end

	sched.run(function()
		local mice = toribio.wait_for_device('mice:/dev/input/mice')
		local lastx, lasty = 0, 0
		mice:register_callback('move', function (x, y)
			if not x then 
				-- timeout with no mouse movements
				generate_output(lastx, lasty)
			else
				generate_output(x, y)
				lastx, lasty = x, y
			end
		end, 0.5)
		
		mice:register_callback('leftbutton', function (v)
			if v then 
				generate_output(0, 0)
				mice.reset_pos(0, 0)
				lastx, lasty = 0, 0
			end
		end)
		
	end)
end

return M
