local M = {}
local toribio = require 'toribio'
local sched = require 'sched'

M.init = function(conf)
	local too_close_event={}
	for sensorname, sconf in pairs(conf.sensors or {}) do
		local sensor=toribio.wait_for_device(sensorname)
		
		local device={}
		device.name='distrigger'
		device.module='distrigger'
		device.events={
			too_close=too_close_event
		}
		device.task = sched.run(function()
			while true do
				if sensor.getValue() < sconf.min_threshold then
					sched.signal( device.events.too_close() )
				end
				sched.sleep( sconf.interval )
			end
		end)
		device.set_pause = function ( pause )
			device.task:set_pause( pause )
		end
		
		toribio.add_device( device )
	end
	
end

return M
