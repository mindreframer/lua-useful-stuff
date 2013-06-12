--- Library for accesing the accelerometer of a OpenMoko.
-- This module starts two devices, one for each one of the acceleration
-- sensors of a OpenMoko FreeRunner smartphone. Runs under SHR-testing OS.
-- The module of both devices is "openmoko\_accel".
-- The acceleration is measured in mg (1/1000th of earth gravity).
-- The first Device is named "accelerometer.1" and the axes are, when 
-- looking from the front and the phone laying on a desk:
-- x (horizontal to the right and away), y (horizontal to the left and away) 
-- and z (down).
-- The second Device is named "accelerometer.2" and the axes are, when 
-- looking from the front and the phone laying on a desk:
-- x (horizontal to the right), y (horizontal and away) 
-- and z (down).
-- @usage local accel = toribio.wait_for_device('accelerometer.1')
--sched.sigrun(
--    {emitter=accel.task, events={accel.events.data}},
--    function(_,_,x,y,z) print (x,y,z) end
--)
-- @module openmoko_accel
-- @alias device

local M = {}
local log = require 'log'

--- Initialize and starts the module.
-- This is called automatically by toribio if the _load_ attribute for the module in the configuration file is set to
-- true.
-- @param conf the configuration table (see @{conf}).
M.init = function(conf)
	local toribio = require 'toribio'
	local nixio = require 'nixio'
	local sched = require 'sched'

	--local sysfs1 = '/sys/devices/platform/lis302dl.1'
	local sysfs1 = '/sys/class/i2c-adapter/i2c-0/0-0073/lis302dl.1'
	local stream1=assert(io.open('/dev/input/event2', 'rb'))
	--local stream1 = assert(nixio.open('/dev/input/event2', nixio.open_flags('rdonly', 'nonblock')))


	--local sysfs2 = '/sys/devices/platform/lis302dl.2'
	local sysfs2 = '/sys/class/i2c-adapter/i2c-0/0-0073/lis302dl.2'
	local stream2=assert(io.open('/dev/input/event3', 'rb'))
	--local stream2 = assert(nixio.open('/dev/input/event3', nixio.open_flags('rdonly', 'nonblock')))

	
	--- Read the acceleration from sensor 1.
	-- The acceleration is measured in mg (1/1000th of earth gravity)
	-- the axis are, when looking from the front and the phone laying on a desk:
	-- x (horizontal to the right and away), y (horizontal to the left and away) 
	-- and z (down)
	-- @return The x, y and z magnitudes.

	--- Read the acceleration from sensor 2.
	-- The acceleration is measured in mg (1/1000th of earth gravity)
	-- the axis are, when looking from the front and the phone laying on a desk:
	-- x (horizontal to the right), y (horizontal and away) 
	-- and z (down)
	-- @return The x, y and z magnitudes.

		
	local function build_device(name, sysfs, stream, event_accel)

		local sysfs_sample_rate = sysfs .. '/sample_rate'
		local sysfs_threshold = sysfs .. '/threshold'
		
		local delay_read = conf.delay or 1
		local task_read = sched.new_task(function()
				local monitor_accel = function(x, y, z)
					for _=1,10 do
						local event = assert(stream:read(16))
						--local time=message:sub(1, 4)
						local etype = event:byte(9) -- only last byte
						local ecode = event:byte(11) -- only last byte
						if etype==3 or etype==2 then
							local value = event:byte(13) + 256*event:byte(14)--2 bytes (~65.5 g)
							if value>32768 then value=value-0xFFFF end
							if ecode==0 then x=value 
							elseif ecode==1 then y=value 
							elseif ecode==2 then z=value end
						elseif etype==0 and ecode==0 then
							return x, y, z
						end
					end
					error('Accelerator sensor fails to sync: '..name)
				end
				local x, y, z
				
				repeat
					x,y,z = monitor_accel(x, y, z)
				until x and y and z
				while true do
					x,y,z = monitor_accel(x, y, z)
					sched.signal(event_accel,x,y,z)
					sched.sleep(delay_read)
				end

			end)

		local device={
			--- Name of the device.
			-- Either 'accelerometer.1' or 'accelerometer.2'
			name=name,
			
			--- Module name.
			-- In this case, "openmoko_accel".
			module="openmoko_accel",
			
			--- Sensor data events.
			-- The events that the sensor can emit.
			-- @field data A data signal, with x,y,z acceleration values as parameters.
			events={
				data=event_accel,
			},
			
			--- Set the sample rate for sensor.
			-- This is the intarnal sample rate, and the known supported values are
			-- 100 and 400 Hz.
			-- @param hz The rate in hz.
			set_rate = function(hz)
				local f=io.open(sysfs_sample_rate, 'w')
				if not f then return end
				f.write(hz..'\n')
				f.close()
			end,
			
			--- Set the threshold for sensor.
			-- Values around 10 or 18 are usual.
			-- @param threshold The threshold value 
			set_threshold = function(threshold)
				local f=io.open(sysfs_threshold, 'w')
				if not f then return end
				f.write(threshold..'\n')
				f.close()
			end,
			
			--- Sensor task.
			-- This is the task that will emit data signals.
			task = task_read,
			
			--- Enable sensing.
			-- This allows to enable and disable the sensing.
			-- @param enable boolean indicating if the sensor data events must be generated.
			-- @param delay time delay between events. If omitted, a configuration value 
			-- is used (field _deviceloaders.openmoko\_accel.delay_), 1 otherwise.
			run = function(enable, delay)
				delay_read = delay or delay_read
				task_read:set_pause(not enable)
			end
		}
		return device
	end
	
	local device1=build_device('accelerometer.1', sysfs1, stream1, {})
	log('OMACCEL', 'INFO', 'Device %s created: %s', device1.module, device1.name)
	toribio.add_device(device1)
	
	local device2=build_device('accelerometer.2', sysfs2, stream2, {})
	log('OMACCEL', 'INFO', 'Device %s created: %s', device2.module, device2.name)
	toribio.add_device(device2)

end

return M

--- Configuration Table.
-- This table is populated by toribio from the configuration file.
-- @table conf
-- @field load whether toribio should start this module automatically at startup.
-- @field delay_read the time between consecutive readngs. Defaults to 1 sec.

