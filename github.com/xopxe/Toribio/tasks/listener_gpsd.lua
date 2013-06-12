local M = {}

M.init = function()
	local sched = require 'sched'
	
	return sched.run(function()
		local toribio = require 'toribio'
		local gpsd = toribio.wait_for_device('gpsd')
		print ('listener gpsd found:', gpsd)
		
		--[[
		local waitd = {
			emitter=mice.task, 
			timeout=conf.timeout or 1, 
			events={'leftbutton', 'rightbutton', 'middlebutton'}
		}
		while true do
			local emitter, ev, v = sched.wait(waitd)
			if emitter then 
				print('mice:', ev, v) 
			else
				print(mice.get_pos.call())
			end
		end
		--]]
		
		---[[
		toribio.register_callback(gpsd, 'VERSION', function(v)
			print('gpsd version:',v.release, v.rev)
			--gpsd.set_watch(true)
		end)
		toribio.register_callback(gpsd, 'DEVICE', function(v)
			print('gpsd device:',v.path, v.bps)
		end)
		toribio.register_callback(gpsd, 'WATCH', function(v)
			print('gpsd watch:',v.enable)
		end)
		toribio.register_callback(gpsd, 'TPV', function(v)
			print('gpsd:', v.mode, v.time, v.lat, v.lon, v.alt )
		end)
		--]]
		sched.sleep(1)
		gpsd.set_watch(true)
	end)
end

return M