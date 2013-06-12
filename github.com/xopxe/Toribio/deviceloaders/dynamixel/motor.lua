--- Library for Dynamixel motors.
-- This library allows to manipulate devices that use Dynamixel 
-- protocol, such as AX-12 robotic servo motors.
-- For basic manipulation, it is enough to use the @{rotate_to_angle} and @{spin} functions,
-- and perhaps set the @{set.torque_enable}. For more sophisticated tasks, the full 
-- Dynamixel functionality is available trough getter and setter functions.  
-- When available, each connected motor will be published
-- as a device in torobio.devices table, named
-- (for example) 'ax12:1', labeled as module 'ax'. Aditionally, an 'ax:all'
-- device will represent the broadcast wide motor. Also, 'ax:sync' motors can be used to 
-- control several motors at the same time. Notice you can not read from broadcast nor sync
-- motors, only send commands to them.  
-- Some of the setable parameters set are located on the motors EEPROM (marked "persist"),
-- and others are on RAM (marked "volatile"). The attributes stored in RAM are reset when the 
-- motor is powered down.  
-- For defaut values, check the Dynamixel documentation.
-- @module dynamixel-motor
-- @usage local toribio = require 'toribio'
--local motor = toribio.wait_for_device('ax12:1')
--motor.set.led(true)
-- @alias Motor

--local my_path = debug.getinfo(1, "S").source:match[[^@?(.*[\/])[^\/]-$]]

local log = require 'log'

local M = {}

local function getunsigned_2bytes(s)
	return s:byte(1) + 256*s:byte(2)
end
local function get2bytes_unsigned(n)
	if n<0 then n=0
	elseif n>1023 then n=1023 end
	local lowb, highb = n%256, math.floor(n/256)
	return lowb, highb
end
local function get2bytes_signed(n)
	if n<-1023 then n=-1023
	elseif n>1023 then n=1023 end
	if n < 0 then n = 1024 - n end
	local lowb, highb = n%256, math.floor(n/256)
	return lowb, highb
end
local function log2( x ) 
	return  math.log( x ) / math.log( 2 )
end

M.get_motor= function (busdevice, motor_id)
	local read_data = busdevice.read_data
	local write_method
	local idb
	local motor_mode -- 'joint' or 'wheel'
	local motor_type  -- 'single', 'sync' or 'broadcast'
	local status_return_level
	
	if type(motor_id) == 'table' then
		motor_type = 'sync'
	elseif motor_id == 0xFE then
		motor_type = 'broadcast'
	else
		motor_type = 'single'
	end
	
	if motor_type~='sync'  then 
		idb = string.char(motor_id)
		write_method='write_data'
	else
		idb = {}
		for i, anid in ipairs(motor_id) do
			idb[i] = string.char(anid)
		end
		write_method='sync_write'
	end


	--Check wether the motor with id actually exists. If not, return nil.
	if motor_type == 'single' then 
		if not busdevice.ping(idb) then
			return nil
		end
	end
	
	-- It exists, let's start building the object.
	local Motor = {
		--- Device file of the bus.
		-- Filename of the bus to which the motor is connected.
		-- For example, _'/dev/ttyUSB0'_
		filename = busdevice.filename, 
		
		--- Bus device.
		-- The dynamixel bus Device to which the motor is connected
		busdevice = busdevice,
		
		--- Dynamixel ID number.
		motor_id = motor_id,
	}
	
	if motor_type == 'single' then
		--- Ping the motor.
		-- Only available for single motors, not sync nor broadcast.
		-- @return a dynamixel error code
		Motor.ping = function()
			return busdevice.ping(idb)
		end
	end	
	
	-- calls that are only avalable on proper motors (not 'syncs motors')
	if motor_type ~= 'sync' then
		--- Reset configuration to factory default.
		-- Use with care, as it also resets the ID number and baud rate. 
		-- For factory defaults, check Dynamixal documentation.
		-- This command only works for single motors (not sync nor broadcast).  
		-- For defaut values, check the Dynamixel documentation.
		-- @return a dynamixel error code
		Motor.reset_factory_default = function()
			return busdevice.reset(idb, status_return_level)
		end
		--- Starts a register write mode.
		-- In reg_write mode changes in configuration to devices
		-- are not applied until a @{reg_write_action} call.  
		-- This command only works for single motors (not sync nor broadcast).
		Motor.reg_write_start = function()
			write_method='reg_write_data'
		end
		--- Finishes a register write mode.
		-- All changes in configuration applied after a previous
		-- @{reg_write_start} are commited.  
		-- This command only works for single motors (not sync nor broadcast).
		Motor.reg_write_action = function()
			busdevice.action(idb,status_return_level)
			write_method='write_data'
		end
	end -- /calls that are only avalable on proper motors (not 'syncs motors')
	
	local control_getters = {
		rotation_mode = function()
			local ret, err = read_data(idb,0x06,4,status_return_level)
			if ret==string.char(0x00,0x00,0x00,0x00) then
				motor_mode = 'wheel'
			else
				motor_mode = 'joint'
			end
			return motor_mode, err
		end,
		
		model_number = function()
			local ret, err = read_data(idb,0x00,2, status_return_level)
			if ret then return getunsigned_2bytes(ret), err end
		end,
		firmware_version = function()
			return read_data(idb,0x02,1, status_return_level)
		end,
		id = function()
			return read_data(idb,0x03,1, status_return_level)
		end,
		baud_rate = function()
			local ret, err = read_data(idb,0x04,1, status_return_level)
			if ret then return math.floor(2000000/(ret+1)), err end --baud
		end,
		return_delay_time = function()
			local ret, err = read_data(idb,0x05,1, status_return_level)
			if ret then return (ret*2)/1000000, err end --sec
		end,
		angle_limit = function()
			local ret, err = read_data(idb,0x06,4, status_return_level)
			if ret then 
				local cw = 0.29*(ret:byte(1) + 256*ret:byte(2))
				local ccw = 0.29*(ret:byte(3) + 256*ret:byte(4))
				return cw, ccw, err 
			end -- deg
		end,
		limit_temperature = function()
			return read_data(idb,0x0B,1, status_return_level)
		end,
		limit_voltage = function()
			local ret, err = read_data(idb,0x0C,2, status_return_level)
			if ret then return ret:byte(1)/10, ret:byte(2)/10, err end
		end,
		max_torque = function()
			local ret, err = read_data(idb,0x0E,2, status_return_level)
			if ret then return getunsigned_2bytes(ret) / 10.23, err  end--% of max torque
		end,
		status_return_level = function()
			local ret, err = read_data(idb,0x10,1, status_return_level or 2)
			local return_levels = {
				[0] = 'ONLY_PING',
				[1] = 'ONLY_READ',
				[2]= 'ALL'
			}
			if ret then 
				local code = ret:byte()
				status_return_level = code
				return return_levels[code], err 
			end 
		end,
		alarm_led = function()
			local ret, err = read_data(idb,0x11,1, status_return_level)
			if ret then 
				return busdevice.has_errors(ret), err
			end
		end,
		alarm_shutdown = function()
			local ret, err = read_data(idb,0x12,1, status_return_level)
			if ret then 
				local _, errorset = busdevice.has_errors(ret)
				return errorset, err  
			end
		end,
		torque_enable = function()
			local ret, err = read_data(idb,0x18,1, status_return_level)
			if ret then return ret:byte()==0x01, err end
		end,
		led = function()
			local ret, err = read_data(idb,0x19,1, status_return_level)
			if ret then return ret:byte()==0x01, err end
		end,
		compliance_margin = function()
			local ret, err = read_data(idb,0x1A,2, status_return_level)
			if ret then return 0.29*ret:byte(1), 0.29*ret:byte(2), err end --deg
		end,
		compliance_slope = function()
			local ret, err = read_data(idb,0x1C,2, status_return_level)
			if ret then
				return log2(ret:byte(1)), log2(ret:byte(2)), err
			end
		end,
		goal_position = function()
			local ret, err = read_data(idb,0x1E,2, status_return_level)
			if ret then 
				local ang=0.29*getunsigned_2bytes(ret)
				return ang, err  -- deg
			end
		end,
		moving_speed = function()
			local ret, err = read_data(idb,0x20,2, status_return_level)
			if ret then 
				local vel = getunsigned_2bytes(ret)
				if motor_mode=='joint' then 
					return vel / 1.496, err --deg/sec
				elseif  motor_mode=='wheel' then
					return vel / 10.23, err --% of max torque
				end
			end
		end,
		torque_limit = function()
			local ret, err = read_data(idb,0x22,2, status_return_level)
			if ret then 
				local ang=getunsigned_2bytes(ret) / 10.23
				return ang, err  -- % max torque
			end
		end,
		present_position = function()
			local ret, err = read_data(idb,0x24,2, status_return_level)
			if ret then 
				local ang=0.29*getunsigned_2bytes(ret)
				return ang, err  -- deg
			end
		end,
		present_speed = function()
			local ret, err = read_data(idb,0x26,2, status_return_level)
			local vel = getunsigned_2bytes(ret)
			if vel > 1023 then vel =1024-vel end
			if motor_mode=='joint' then 
				return vel / 1.496, err --deg/sec
			elseif  motor_mode=='wheel' then
				return vel / 10.23, err --% of max torque
			end
		end,
		present_load = function()
			local ret, err = read_data(idb,0x28,2, status_return_level)
			if ret then 
				local load = ret:byte(1) + 256*ret:byte(2)
				if load > 1023 then load = 1024-load end
				return load/10.23, err -- % of torque max
			end
		end,
		present_voltage = function()
			local ret, err = read_data(idb,0x2A,1, status_return_level)
			if ret then return ret:byte()/10, err end
		end,
		present_temperature = function()
			local ret, err = read_data(idb,0x2B,1, status_return_level)
			if ret then return ret:byte(), err end
		end,
		registered = function()
			local ret, err = read_data(idb,0x2C,1, status_return_level)
			if ret then return ret:byte()==1, err end --bool
		end,
		moving = function()
			local ret, err = read_data(idb,0x2E,1, status_return_level)
			if ret then return ret:byte()==1, err end --bool
		end,
		lock = function()
			local ret, err = read_data(idb,0x2F,1, status_return_level)
			if ret then return ret:byte()==1, err end --bool
		end,
		punch = function()
			local ret, err = read_data(idb,0x30,2, status_return_level)
			if ret then 
				local load = ret:byte(1) + 256*ret:byte(2)
				return load/10.23, err -- % of torque max
			end
		end
	}
	
	local control_setters = {
		rotation_mode = function (mode)
			local ret 
			if mode == 'wheel' then
				ret = busdevice[write_method](idb,0x06,string.char(0, 0, 0, 0),status_return_level)
			else
				local max=1023
				local maxlowb, maxhighb = get2bytes_unsigned(max)
				ret = busdevice[write_method](idb,0x06,string.char(0, 0, maxlowb, maxhighb),status_return_level)
			end
			motor_mode = mode
			return ret
		end,
		id = function(newid)
			assert(newid>=0 and newid<=0xFD, 'Invalid ID: '.. tostring(newid))
			motor_id, idb = newid, string.char(newid)
			return busdevice[write_method](idb,0x3,string.char(newid),status_return_level)
		end,
		baud_rate = function(baud)
			local n = math.floor(2000000/baud)-1
			assert(n>=1 and n<=207, "Attempt to set serial speed: "..n)
			return busdevice[write_method](idb,0x04,n,status_return_level)
		end,
		return_delay_time = function(sec)
			local parameter = math.floor(sec * 1000000 / 2)
			return busdevice[write_method](idb,0x05,string.char(parameter),status_return_level)
		end,
		angle_limit = function(cw, ccw)
			if cw then cw=math.floor(cw/0.29)
			else cw=0 end
			if ccw then ccw=math.floor(ccw/0.29)
			else ccw=1023 end
			local minlowb, maxhighb = get2bytes_unsigned(cw)
			local maxlowb, maxnhighb = get2bytes_unsigned(ccw)
			local ret = busdevice[write_method](idb,0x06,string.char(minlowb, maxhighb, maxlowb, maxnhighb),status_return_level)
			if cw==0 and ccw==0 then 
				motor_mode='wheel' 
			else
				motor_mode='joint' 
			end
			return ret
		end,
		limit_temperature = function(deg)
			return busdevice[write_method](idb,0x0B,deg,status_return_level)
		end,
		limit_voltage = function(min, max)
			local min, max = min*10, max*10
			if min<=255 and min>0 and max<=255 and max>0 then 
				return busdevice[write_method](idb,0x0C,string.char(min, max),status_return_level)
			end
		end,
		max_torque = function(value)
			-- 0% ..  100% max torque
			local torque=math.floor(value * 10.23)
			local lowb, highb = get2bytes_unsigned(torque)
			return busdevice[write_method](idb,0x0E,string.char(lowb,highb),status_return_level)
		end,
		status_return_level = function(level)
			local level_codes= {
				ONLY_PING = 0,
				ONLY_READ = 1,
				ALL = 2
			}
			local code = level_codes[level or 'ALL']
			status_return_level = code
			return busdevice[write_method](idb,0x10,string.char(code),status_return_level or 2)
		end,
		alarm_led = function(errors)
			local code = 0
			for _, err in ipairs(errors) do
				code = code + (busdevice.ax_errors[err] or 0)
			end
			return busdevice[write_method](idb,0x11,string.char(code),status_return_level)
		end,
		alarm_shutdown = function(errors)
			local code = 0
			for _, err in ipairs(errors) do
				code = code + (busdevice.ax_errors[err] or 0)
			end
			return busdevice[write_method](idb,0x12,string.char(code),status_return_level)
		end,
		torque_enable = function (value)
			--boolean
			local parameter
			if value then 
				parameter=string.char(0x01)
			else
				parameter=string.char(0x00)
			end
			return busdevice[write_method](idb,0x18,parameter,status_return_level)
		end,
		led = function (value)
			local parameter
			if value then 
				parameter=string.char(0x01)
			else
				parameter=string.char(0x00)
			end
			assert(status_return_level, debug.traceback())
			return busdevice[write_method](idb,0x19,parameter,status_return_level)
		end,
		compliance_margin = function(angle)
			local ang=math.floor(angle/0.29)
			local lowb, highb = get2bytes_unsigned(ang)
			return busdevice[write_method](idb,0x1A,string.char(lowb,highb),status_return_level)
		end,
		compliance_slope = function(cw, ccw)
			cw, ccw = math.floor(2^cw), math.floor(2^ccw)
			return busdevice[write_method](idb,0x1C,string.char(cw,ccw),status_return_level)
		end,
		goal_position = function(angle)
			local ang=math.floor(angle/0.29)
			local lowb, highb = get2bytes_unsigned(ang)
			return busdevice[write_method](idb,0x1E,string.char(lowb,highb),status_return_level)
		end,
		moving_speed = function(value)
			if motor_mode=='joint' then
				-- 0 .. 684 deg/sec
				local vel=math.floor(value * 1.496)
				local lowb, highb = get2bytes_unsigned(vel)
				return busdevice[write_method](idb,0x20,string.char(lowb,highb),status_return_level)
			elseif motor_mode=='wheel' then
				-- -100% ..  +100% max torque
				local vel=math.floor(value * 10.23)
				local lowb, highb = get2bytes_signed(vel)
				return busdevice[write_method](idb,0x20,string.char(lowb,highb),status_return_level)
			end
		end,
		torque_limit = function(value)
			-- 0% ..  100% max torque
			local torque=math.floor(value * 10.23)
			local lowb, highb = get2bytes_unsigned(torque)
			return busdevice[write_method](idb,0x22,string.char(lowb,highb),status_return_level)
		end,
		lock = function(enable)
			local parameter
			if enable then 
				parameter=string.char(0x01)
			else
				parameter=string.char(0x00)
			end
			return busdevice[write_method](idb,0x2F,parameter,status_return_level)
		end,
		punch = function(value)
			-- 0% ..  100% max torque
			local torque=math.floor(value * 10.23)
			local lowb, highb = get2bytes_unsigned(torque)
			return busdevice[write_method](idb,0x30,string.char(lowb,highb),status_return_level)
		end
	}
	
	local last_speed
	--- Rotate to the indicated angle.
	-- @param angle Position in degrees in the 0-300 range.
	-- @param speed optional rotational speed, in deg/sec in the 1 .. 684 range. 
	-- Defaults to max unregulated speed.
	Motor.rotate_to_angle = function (angle, speed)
		if motor_mode ~= 'joint' then
			control_setters.rotation_mode('joint')
		end
		if speed ~= last_speed then 
			control_setters.moving_speed(speed or 0)
		end
		return control_setters.goal_position(angle)
	end 
	
	--- Spin at the indicated torque. 
	-- @param power % of max torque, in the -100% .. 100% range.
	Motor.spin = function (power)
		if motor_mode ~= 'joint' then
			control_setters.rotation_mode('wheel')
		end
		return control_setters.moving_speed(power)
	end
	
	Motor.set = control_setters
	
	--- Name of the device.
	-- Of the form _'ax12:5'_, _ax:all_ for a broadcast motor, or ax:sync (sync motor set).
	--- Module name (_'ax'_, ax-all or _'ax-sync'_ in this case)
	-- _'ax'_ is for actuators, _'ax-sync'_ is for sync-motor objects
	if motor_type=='sync' then
		--initialize local state
		status_return_level = 0
		
		Motor.module = 'ax-sync'
		Motor.name = 'ax-sync:'..tostring(math.random(2^30))
	elseif motor_type=='broadcast' then
		--initialize local state
		status_return_level = 0

		Motor.module = 'ax-all'
		Motor.name = 'ax:all'
	elseif motor_type=='single' then
		Motor.get = control_getters
		
		--initialize local state
		_, _ = control_getters.status_return_level() 
		_, _ = control_getters.rotation_mode()
		
		Motor.module = 'ax'
		Motor.name = 'ax'..((control_getters.model_number()) or '??')..':'..motor_id
	end
	
	log('AXMOTOR', 'INFO', 'device object created: %s', Motor.name)
	
	--toribio.add_device(busdevice)
	return Motor
end

return M

--- Atribute getters.
-- Functions used to get values from the Dynamixel control table. These functions
-- are not available for broadcast nor sync motors.
-- @section getters

--- Get the dynamixel model number.
-- For an AX-12 this will return 12.
-- @function get.model_number
-- @return a model number, followed by a dynamixel error code.

--- Get the version of the actuator's firmware.
-- For an AX-12 this will return 12.
-- @function get.firmware_version
-- @return a version number, followed by a dynamixel error code.

--- Get the ID number of the actuator.
-- @function get.id
-- @return a ID number, followed by a dynamixel error code.

--- Get the baud rate.
-- @function get.baud_rate
-- @return a serial bus speed in bps, followed by a dynamixel error code.

--- Get the response delay.
-- The time in secs an actuator waits before answering a call.
-- @function get.return_delay_time
-- @return the edlay time in secs, followed by a dynamixel error code.

--- Get the rotation mode.
--  Wheel mode is equivalent to having limits cw=0, ccw=0, and mode joint is equivalent to cw=0, ccw=300
-- @function get.rotation_mode
-- @return Either 'wheel' or 'joint', followed by a dynamixel error code.

--- Get the angle limit.
--  The extreme positions possible for the Joint mode.
-- @function get.angle_limit
-- @return the cw limit, then the ccw limit, followed by a dynamixel error code.

--- Get the temperature limit.
-- @function get.limit_temperature
-- @return The maximum allowed temperature in degrees Celsius, followed by a dynamixel error code.

--- Get the voltage limit.
-- @function get.limit_voltage
-- @return The minumum and maximum allowed voltage in Volts, followed by a dynamixel error code.

--- Get the torque limit.
-- This is also the default value for `torque_limit`.
-- @function get.max_torque
-- @return the maximum producible torque, as percentage of maximum possible (in the 0% - 100% range), 
-- followed by a dynamixel error code.

--- Get the Return Level.
-- Control what commands must generate a status response 
-- from the actuator. Possible values are 'ONLY\_PING', 'ONLY\_READ' and 'ALL' (default)
-- @function get.status_return_level
-- @return the return level, followed by a dynamixel error code.

--- Get the LED alarm setup.
-- A list of error conditions that cause the LED to blink.
-- @function get.alarm_led
-- @return A double indexed set, by entry number and error code, followed by a dynamixel error code. The possible 
-- error codes in the list are 'ERROR\_INPUT\_VOLTAGE', 'ERROR\_ANGLE\_LIMIT', 'ERROR\_OVERHEATING', 
-- 'ERROR\_RANGE', 'ERROR\_CHECKSUM', 'ERROR\_OVERLOAD' and 'ERROR\_INSTRUCTION'.

--- Get the alarm shutdown setup.
-- A list of error conditions that cause the  `torque_limit` attribute to
-- be set to 0, halting the motor.
-- @function get.alarm_shutodown
-- @return A double indexed set, by entry number and error code, followed by a dynamixel error code. The possible 
-- error codes in the list are 'ERROR\_INPUT\_VOLTAGE', 'ERROR\_ANGLE\_LIMIT', 'ERROR\_OVERHEATING', 
-- 'ERROR\_RANGE', 'ERROR\_CHECKSUM', 'ERROR\_OVERLOAD' and 'ERROR\_INSTRUCTION'.

--- Get the Torque Enable status.
-- Control the power supply to the motor.
-- @function get.torque_enable
-- @return Boolean

--- Get the Compliance Margin.
--  See Dynamiel reference.
-- @function get.compliance_margin
-- @return cw margin, ccw margin (both in degrees), followed by a Dynamiel error code.

--- Get the Compliance Slope.
-- See Dynamiel reference.
-- @function get.compliance_slope
-- @return the step value, followed by a Dynamiel error code.

--- Get the Punch value.
-- See Dynamiel reference.
-- @function get.punch
-- @return punch as % of max torque (in the 0..100 range)

--- Get the goal angle.
-- The target position for the actuator is going to. Only works in joint mode.
-- @function get.goal_position
-- @return the target angle in degrees, followed by a Dynamiel error code.

--- Get rotation speed.
-- @function get.moving_speed
-- @return If motor in joint mode, speed in deg/sec (0 means max unregulated speed), if in wheel
-- mode, as a % of max torque, followed by a Dynamiel error code.

--- Get the torque limit.
-- Controls the 'ERROR\_OVERLOAD' error triggering.
-- @function get.torque_limit
-- @return  The torque limit as percentage of maximum possible.
-- If in wheel mode, as a % of max torque (in the -100 .. 100 range)
-- , followed by a Dynamiel error code.

--- Get the axle position.
-- @function get.present_position
-- @return The current position of the motor axle, in degrees (only valid in the
-- 0 .. 300 range), followed by a Dynamiel error code.

--- Get the actual rotation speed.
-- Only valid in the 0..300 deg position.
-- @function get.present_speed
-- @return If motor in joint mode, speed in deg/sec, if in wheel
-- mode, as a % of max torque, followed by a Dynamiel error code.

--- Get the motor load.
-- Only valid in the 0..300 deg position, and aproximate.
-- @function get.present_load
-- @return Percentage of max torque (positive is clockwise, negative is 
-- counterclockwise), followed by a Dynamiel error code.

--- Get the supplied voltage.
-- @function get.present_voltage
-- @return The supplied voltage in Volts, followed by a Dynamiel error code.

--- Get the internal temperature.
-- @function get.present_temperature
-- @return The Internal temperature in degrees Celsius, followed by a Dynamiel error code.

--- Get registered commands status.
-- Wether there are registerd commands (see @{reg_write_start} and @{reg_write_action})
-- @function get.registered
-- @return A boolean, followed by a Dynamiel error code.

--- Get the moving status.
-- Wether the motor has reached @{get.goal_position}.
-- @function get.present_temperature
-- @return A boolean, followed by a Dynamiel error code.

--- Get the lock status.
-- Whether the EEPROM (persistent) attributes are blocked for writing.
-- @function get.lock
-- @return boolean, followed by a Dynamiel error code.

--- Atribute setters.
-- Functions used to set values for the Dynamixel control table. 
-- Some of the setable parameters set are located on the motors EEPROM (marked "persist"),
-- and others are on RAM (marked "volatile"). The attributes stored in RAM are reset when the 
-- motor is powered down.  
-- @section setters

--- Set the ID number of the actuator (persist).
--- @function set.id
-- @param ID number, must be in the 0 .. 253 range.
-- @return A dynamixel error code.

--- Set the baud rate (persist).
-- @function set.baud_rate
-- @param bps bus rate in bps, in the 9600 to 1000000 range. Check the Dynamixel docs for supported values.
-- @return A dynamixel error code.

--- Set the response delay (persist).
-- The time in secs an actuator waits before answering a call.
-- @function set.return_delay_time
-- @param sec a time in sec.
-- @return A dynamixel error code.

--- Set the rotation mode (persist).
--  Wheel mode is for continuous rotation, Joint is for servo. Setting this attribute resets the 
-- `angle_limit` parameter. Wheel mode is equivalent to having limits cw=0, ccw=0, and mode joint is equivalent to cw=0, ccw=300
-- @function set.rotation_mode
-- @param mode Either 'wheel' or 'joint'.
-- @return A dynamixel error code.

--- Set the angle limit (persist).
--  The extreme positions possible for the Joint mode. The angles are given in degrees, and must be in the 0<=cw<=ccw<=300 range.
-- @function set.angle_limit
-- @param cw the clockwise limit.
-- @param ccw the clockwise limit.
-- @return A dynamixel error code.

--- Set the temperature limit  (persist).
-- @function set.limit_temperature
-- @param deg the temperature in degrees Celsius.
-- @return A dynamixel error code.

--- Set the voltage limit  (persist).
-- @function set.limit_voltage
-- @param min the minimum allowed voltage in Volts.
-- @param max the maximum allowed voltage in Volts.
-- @return A dynamixel error code.

--- Set the torque limit  (persist).
-- This is also the default value for `torque_limit`.
-- @function set.max_torque
-- @param torque the maximum producible torque, as percentage of maximum possible (in the 0% - 100% range)
-- @return A dynamixel error code.


--- Set the Return Level (persist).
-- Control what commands must generate a status response 
-- from the actuator. 
-- @function set.status_return_level
-- @param return_level Possible values are 'ONLY\_PING', 'ONLY\_READ' and 'ALL' (default)
-- @return A dynamixel error code.

--- Set LED alarm (persist).
-- A list of error conditions that cause the LED to blink.
-- @function set.alarm_led
-- @param  errors A list of error codes. The possible 
-- error codes are 'ERROR\_INPUT\_VOLTAGE', 'ERROR\_ANGLE\_LIMIT', 'ERROR\_OVERHEATING', 
-- @return A dynamixel error code.

--- Set alarm shutdown (persist).
-- A list of error conditions that cause the  `torque_limit` attribute to
-- be set to 0, halting the motor.
-- @function set.alarm_shutodown
-- @param  errors A list of error codes. The possible 
-- error codes are 'ERROR\_INPUT\_VOLTAGE', 'ERROR\_ANGLE\_LIMIT', 'ERROR\_OVERHEATING', 
-- @return A dynamixel error code.

--- Set the Torque Enable status (volatile).
-- Control the power supply to the motor.
-- @function set.torque_enable
-- @param status Boolean
-- @return A dynamixel error code.

--- Set the Compliance Margin (volatile).
-- See Dynamiel reference.
-- @function set.compliance_margin
-- @param cw clockwise margin, in deg.
-- @param ccw counterclockwise margin, in deg.
-- @return A dynamixel error code.

--- Set the Compliance Slope (volatile).
-- See Dynamiel reference.
-- @function set.compliance_slope
-- @param step the step value.
-- @return A dynamixel error code.

--- Set the Punch value (volatile).
-- See Dynamiel reference.
-- @function set.punch
-- @param punch as % of max torque (in the 0..100 range)
-- @return A dynamixel error code.

--- Set the goal angle (volatile).
-- The target position for the actuator to go, in degrees. Only works in joint mode.
-- @function set.goal_position
-- @param angle the target angle in degrees
-- @return A dynamixel error code.

--- Set the rotation speed (volatile).
-- @function set.moving_speed
-- @param speed If motor in joint mode, speed in deg/sec in the 0 .. 684 range 
-- (0 means max unregulated speed).  
-- If in wheel mode, as a % of max torque (in the -100 .. 100 range).
-- @return A dynamixel error code.

--- Set the torque limit (volatile).
-- Controls the 'ERROR\_OVERLOAD' error triggering.
-- @function set.torque_limit
-- @param torque The torque limit as percentage of maximum possible.
-- If in wheel mode, as a % of max torque (in the -100 .. 100 range).
-- @return A dynamixel error code.

--- Set the lock status (volatile).
-- @function set.lock
-- @param lock once set to true, can be unlocked only powering down the motor.  
-- @return A dynamixel error code.

