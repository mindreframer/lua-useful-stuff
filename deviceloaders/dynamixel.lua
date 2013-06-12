--- Library for Dynamixel protocol.
-- This library allows to manipulate devices that use Dynamixel
-- protocol, such as AX-12 robotic servo motors.
-- When available, a dynamixel bus will be represented by a Device
-- object in toribio.devices table. The device will be named (as an
-- example), "dynamixel:/dev/ttyUSB0".
-- @module dynamixel-bus
-- @alias busdevice

local M = {}

local toribio = require 'toribio'
local sched = require 'sched'
local ax = require 'deviceloaders/dynamixel/motor'
local log = require 'log'

--local my_path = debug.getinfo(1, "S").source:match[[^@?(.*[\/])[^\/]-$]]

local BROADCAST_ID = string.char(0xFE)
local PACKET_START = string.char(0xFF,0xFF)

local INSTRUCTION_PING = string.char(0x01)
local INSTRUCTION_READ_DATA = string.char(0x02)
local INSTRUCTION_WRITE_DATA = string.char(0x03)
local INSTRUCTION_REG_WRITE = string.char(0x04)
local INSTRUCTION_ACTION = string.char(0x05)
local INSTRUCTION_RESET = string.char(0x06)
local INSTRUCTION_SYNC_WRITE = string.char(0x83)

local ax_errors = {
	--[0x00] = 'NO_ERROR',
	ERROR_INPUT_VOLTAGE = 0x01,
	ERROR_ANGLE_LIMIT = 0x02,
	ERROR_OVERHEATING = 0x04,
	ERROR_RANGE = 0x08,
	ERROR_CHECKSUM = 0x10,
	ERROR_OVERLOAD = 0x20,
	ERROR_INSTRUCTION = 0x40,
}

local function generate_checksum(data)
	local checksum = 0
	for i=1, #data do
		checksum = checksum + data:byte(i)
	end
	return 255 - (checksum%256)
end

--- Initialize and start the module.
-- This is called automatically by toribio if the _load_ attribute for the module in the configuration file is set to
-- true.
-- @param conf the configuration table (see @{conf}).
M.init = function (conf)
	local ax_bus = require 'deviceloaders/dynamixel/serial'.new_bus(conf)
	
	local function buildAX12packet(id, payload)
		local data = id..string.char(#payload+1)..payload
		local checksum = generate_checksum(data)
		local packet = PACKET_START..data..string.char(checksum)
		return packet
	end
	
	local sendAX12packet = ax_bus.sendAX12packet
	
	local ping = function(id)
		id = id or BROADCAST_ID
		local packet_ping = buildAX12packet(id, INSTRUCTION_PING)
		return sendAX12packet(packet_ping, id,  id ~= BROADCAST_ID)
	end
	local write_data_now = function(id,address,data, return_level)
		id = id or BROADCAST_ID
		local packet_write = buildAX12packet(id,
			INSTRUCTION_WRITE_DATA..string.char(address)..data)
		return sendAX12packet(packet_write, id, return_level>=2 and id ~= BROADCAST_ID)
	end
	local read_data = function(id,startAddress,length, return_level)
		if id==BROADCAST_ID then return nil, 'read from broadcast' end
		local packet_read = buildAX12packet(id,
			INSTRUCTION_READ_DATA..string.char(startAddress)..string.char(length))
		local err, data = sendAX12packet(packet_read, id, return_level>=1)
		if data and #data ~= length then return nil, 'read error' end
		assert(data~=nil or err~=nil, debug.traceback())
		return data, err
	end
	local reg_write_data = function(id,address,data, return_level)
		id = id or BROADCAST_ID
		local packet_reg_write = buildAX12packet(id,
			INSTRUCTION_REG_WRITE..string.char(address)..data)
		return sendAX12packet(packet_reg_write, id, return_level>=2 and id ~= BROADCAST_ID)
	end
	local action = function(id, return_level)
		id = id or BROADCAST_ID
		local packet_action = buildAX12packet(id, INSTRUCTION_ACTION)
		return sendAX12packet(packet_action, id, return_level>=2 and id ~= BROADCAST_ID)
	end
	local reset_factory_default = function(id, return_level)
		id = id or BROADCAST_ID
		local packet_reset = buildAX12packet(id, INSTRUCTION_RESET)
		return sendAX12packet(packet_reset, id, return_level>=2 and id ~= BROADCAST_ID)
	end
	local sync_write = function(ids, address,data)
		local dataout = string.char(address)..string.char(#data)
		for i=1, #ids do
			local sid = ids[i]
			dataout=dataout..sid..data
		end
		local sync_packet = buildAX12packet(BROADCAST_ID,
			INSTRUCTION_SYNC_WRITE..dataout)
		sendAX12packet(sync_packet, ids, false)
	end
	-- -----------------------------------------
	
	local busdevice = {
		ping = ping,
		reset_factory_default = reset_factory_default,
		read_data =read_data,
		write_data = write_data_now,
		reg_write_data = reg_write_data,
		action = action,
		sync_write = sync_write,
	}

	--- Motors connected to the bus.
	-- The keys are device numbers, the values are Motor objects.
	busdevice.motors = {}
	
	local filename=conf.filename or '??'
	
	--- Name of the device.
	-- Of the form _'dynamixel:/dev/ttyUSB0'_
	busdevice.name = 'dynamixel:'..filename
	
	--- Module name (in this case, _'dynamixel'_).
	busdevice.module = 'dynamixel'
	
	--- Device file of the bus.
	-- For example, '/dev/ttyUSB0'
	busdevice.filename = filename
	
	-- --- Set the ID of a motor.
	-- Use with caution: all motors connected to the bus will be
	-- reconfigured to the new ID.
	-- @param newid ID number to set.
	busdevice.set_id = function(newid)
		assert(newid>=0 and newid<=0xFD, 'Invalid ID: '.. tostring(newid))
		local idb=string.char(id)
		busdevice.write_data(BROADCAST_ID,0x03,idb)
	end

	--- Get a broadcasting Motor object.
	-- All commands sent to this motor will be broadcasted
	-- to all motors.
	-- @return A Motor object.
	busdevice.get_broadcaster = function()
		return busdevice.get_motor(0xFE)
	end
	
	--- Get a Motor object.
	-- @param id The numeric ID of the motor
	-- @return A Motor object, or nil if not such ID found.
	busdevice.get_motor = function(id)
		if busdevice.motors[id] then return busdevice.motors[id] end
		local motor=ax.get_motor(busdevice, id)
		busdevice.motors[id] = motor
		return motor
	end
	
	--- Get a Sync-motor object.
	-- A sync-motor allows to control several actuators with a single command.
	-- The commands will be applied to all actuators it represents.
	-- The "get" methods are not available.
	-- @param ... A set of motor Device objects or numeric IDs
	-- @return a sync_motor object
	busdevice.get_sync_motor = function(...)
		local ids = {}
		for i=1, select('#', ...)  do
			local m = select(i, ...)
			if type (m) == 'number' then
				local motor = busdevice.get_motor(m)
				if motor then ids[#ids+1] = motor.id end
			else
				ids[#ids+1] = m.id
			end
		end
		return ax.get_motor(busdevice, ids)
	end
	
	--- Decodes dynamixel error codes.
	-- @param code A dynamixel error code as returned by the different motor methods.
	-- @return A set of error strings. The possible error strings are 'ERROR\_INPUT\_VOLTAGE', 'ERROR\_ANGLE\_LIMIT',
	-- 'ERROR\_OVERHEATING', 'ERROR\_RANGE', 'ERROR\_CHECKSUM', 'ERROR\_OVERLOAD', 'ERROR\_INSTRUCTION'.  
	-- The table is double-indexed by entry number to allow array-like traversal.
	-- @usage local errorset = dynamixel.has_errors(0x10+0x08)
	--print ("has errors:" #errorset>0 )
	--print ("has range error:", errorset['ERROR_RANGE']==true )
	busdevice.has_errors = function (code)
		local errorset = {}
		if code~=0 then
			for err, n in pairs(ax_errors) do
				if (math.floor(code / n) % 2)==1 then
					errorset[err] = true
					errorset[#errorset+1] = err
				end
			end
		end
		return errorset
	end
	
	busdevice.ax_errors = ax_errors
	
	log('AX', 'INFO', 'Device %s created: %s', tostring(busdevice.module), tostring(busdevice.name))
	toribio.add_device(busdevice)

	--- Signals emitted by this device.
	-- @field discovery_end The discovery of attached motors has finished.
	-- @table events
	busdevice.events = {
		discovery_end ={},
	}
	
	--- The bus scannning status.
	-- This flag will be set to true once the bus has been scanned and all motors discovered..
	busdevice.discovery_finished = false
	
	--- Task that will emit signals associated to this device.
	busdevice.task = sched.run(function()
		--local dm = busdevice.api
		for i = 0, 253 do
			local motor = busdevice.get_motor(i)
			--print('XXXXXXXX',i, (motor or {}).name)
			if motor then
				--busdevice.events[i] = string.char(i)
				log('AX', 'INFO', 'Device %s created: %s', motor.module, motor.name)
				toribio.add_device(motor)
			end
			--sched.yield()
		end
		busdevice.discovery_finished = true
		sched.signal(busdevice.events.discovery_end)
	end)
end

return M

--- Configuration Table.
-- When the start is done automatically (trough configuration), 
-- this table points to the modules section in the global configuration table loaded from the configuration file.
-- @table conf
-- @field load whether toribio should start this module automatically at startup.
-- @field filename the device file for the serial bus (defaults to '/dev/ttyUSB0').
-- @field serialtimeout the timeout when waiting for a response from an actuator (defaults to 0.05s)
-- @field stty_flags parameters to pass to stty for configuring the serial bus.
-- @field serialspeed serial bus speed in bps (defaults to 1000000).
