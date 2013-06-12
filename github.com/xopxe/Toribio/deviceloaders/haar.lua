--- Library for accesing Haar clasificator.
-- The device will be named "haar", module "haar", and will generate signals
-- from a external program using OpenCV (see deviceloaders/haar/haar\_stream.py). 
-- The external haar\_stream.py must be started separately.
-- @module haar
-- @alias device

local M = {}

local run_shell = function(s)
	local f = io.popen(s) -- runs command
	local l = f:read("*a") -- read output of command
	f:close()
	return l
end

--- Initialize and starts the module.
-- This is called automatically by toribio if the _load_ attribute for the module in the configuration file is set to
-- true.
-- @param conf the configuration table (see @{conf}).
M.init = function(conf)
	local toribio = require 'toribio'
	local selector = require 'tasks/selector'
	local sched = require 'sched'
	local log = require 'log'
	
	local ip = conf.ip or '127.0.0.1'
	local port = conf.port or 45454
	local event_match= {}

	local function get_incomming_handler()
		return function(sktd, data, err) 
			--print ('', data)
			if not data then sched.running_task:kill() end
			local x, y, sx, sy = string.match(data, '^(%S+)%s(%S+)%s(%S+)%s(%S+)$')
			--assert(x and y and sx and sy)
			if x and y and sx and sy then 
				sched.signal(event_match, tonumber(x), tonumber(y), 
					tonumber(sx), tonumber(sy)) 
			else
				log('HAAR', 'ERROR', 'failed to decode data with length %s"', tostring(#data))
			end
			return true
		end
	end
	
	local device={
		--- Name of the device (in this case, 'haar').
		name = 'haar', 
		
		--- Module name (in this case, 'haar').
		module = 'haar', 
		
		--- Task that will emit signals associated to this device.
		task = selector.task,  
		
		--- Events emitted by this device.
		-- @field match a match has been received. Parameters are centerx, centery, sizex, sizey
		-- of the matching area.
		events = { 
			match = event_match,
		},
		
		sktd = selector.new_udp(nil, nil, ip, port, -1, get_incomming_handler()),
	}
	
	
	log('HAAR', 'INFO', 'Device %s created: %s', device.module, device.name)
	toribio.add_device(device)
end

return M

--- Configuration Table.
-- This table is populated by toribio from the configuration file.
-- @table conf
-- @field load whether toribio should start this module automatically at startup.
-- @field ip where listen for the haar\_stream.py data (defaults to '127.0.0.1')
-- @field port where listen for the haar\_stream.py data (defaults to 45454)

