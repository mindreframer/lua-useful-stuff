--- Library for accesing gpsd.
-- The device will be named "gpsd", module "gpsd", and will generate signals
-- from gpsd. The gpsd service must be started. For an example using this module, 
-- see listener_gpsd.lua
-- @module gpsd
-- @alias device

local M = {}

--- Initialize and starts the module.
-- This is called automatically by toribio if the _load_ attribute for the module in the configuration file is set to
-- true.
-- @param conf the configuration table (see @{conf}).
M.init = function(conf)
	local toribio = require 'toribio'
	local selector = require 'tasks/selector'
	local sched = require 'sched'
	local json = require 'lib/dkjson'
	local log = require 'log'
	
	local ip = conf.ip or '127.0.0.1'
	local port = conf.port or 2947
	
	local device={
		--- Name of the device (in this case, 'gpsd').
		name = 'gpsd', 
		
		--- Module name (in this case, 'gpsd').
		module = 'gpsd', 
		
		--- Task that will emit signals associated to this device.
		task = selector.task,  
		
		--- Events emitted by this device.
		-- Each event represent a gpsd event. The signal has a single
		-- parameter, a table containing the gpsd provided data.
		-- @field VERSION
		-- @field WATCH
		-- @field DEVICES
		-- @field DEVICE
		-- @field SKY
		-- @field TPV
		-- @field AIS
		events = { 
			VERSION = {},
			WATCH = {}, 
			DEVICES = {},
			DEVICE = {},
			SKY = {}, 
			TPV = {}, 
			AIS = {},
		},
	}
	local events=device.events
	
	local function get_incomming_handler()
		local buff = ''
		return function(sktd, data, err) 
			--print ('', data)
			if not data then return end
			buff = buff .. data
			--print ('incomming', buff)
			local decoded, index, e = json.decode(buff)
			if decoded then 
				--print ('','',decoded.class)
				buff = buff:sub(index)
				sched.signal(events[decoded.class], decoded) 
			else
				log('GPSD', 'ERROR', 'failed to jsondecode buff  with length %s with error "%s"', tostring(#buff), tostring(index).." "..tostring(e))
			end
			return true
		end
	end
	local sktd_gpsd = selector.new_tcp_client(ip, port, nil, nil, 'line', get_incomming_handler())
	
	--- Start and Stop gpsd watching.
	-- @param enable true to start, false to stop
	device.set_watch = function(enable)
		if enable then 
			log('GPSD', 'INFO', 'Watch enabled')
			sktd_gpsd:send_sync('?WATCH={"enable":true,"json":true}\r\n')
		else
			log('GPSD', 'INFO', 'Watch disabled')
			sktd_gpsd:send_sync('?WATCH={"enable":false}\r\n')
		end
	end
	
	log('GPSD', 'INFO', 'Device %s created: %s', device.module, device.name)
	toribio.add_device(device)
end

return M

--- Configuration Table.
-- This table is populated by toribio from the configuration file.
-- @table conf
-- @field load whether toribio should start this module automatically at startup.
-- @field ip of the gpsd daemon (defaults to '127.0.0.1')
-- @field port of the gpsd daemon (defaults to 2947)
