--- Library for using a Rnr content based bus.
-- @module rnr_client
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
	local log = require 'log'
	
	local ip = conf.ip or '127.0.0.1'
	local port = conf.port or 8182
	
	local function parse_params(data)
		local params={}
		local k, v
		for _, linea in ipairs(data) do
			k, v =  string.match(linea, "^%s*(.-)%s*=%s*(.-)%s*$")
			if k and v then
				params[k]=v
			end
		end
		
		for k, v in pairs(params) do
			params[k]=v
		end
		return params
	end
	
	local device={
		--- Name of the device (in this case, 'rnr_client').
		name = 'rnr_client', 
		
		--- Module name (in this case, 'rnr_client').
		module = 'rnr_client', 
		
	}
	
	--- Open a new connection.
	-- The descriptor allows object-oriented acces to methods, like connd:emite_notification(data)
	-- @return a connection descriptor (see @{connd}) on success, _nil, message_ on failure.
	device.new_connection = function ()
		local notification_arrival = {} --signal
		local function get_incomming_handler()
			local notification_lines
			return function(sktd, line, err) 
				--print ('++++++++', sktd, line, err)
				--if not line then return end
				
				if line == 'NOTIFICATION' then
					notification_lines = {}
				elseif line == 'END' then
					if notification_lines then
						local notification = parse_params(notification_lines)
						sched.signal(notification_arrival, notification)
						notification_lines = nil
					end
				elseif notification_lines then
					notification_lines[#notification_lines+1]=line
				end
				
				return true
			end
		end
		local skt, err = selector.new_tcp_client(ip, port, nil, nil, 'line', get_incomming_handler())
		if not skt then 
			log('RNRCLIENT', 'ERROR', 'Failed to connect to %s:%s with error: %s', tostring(ip), tostring(port),tostring(err))
			return nil, err
		end
		local connd = setmetatable({
			task = selector.task,  
			
			events = { 
				notification_arrival = notification_arrival
			},
			
			skt = skt,
		}, {__index=device})
		return connd
	end
	
	--- Add a Subscription.
	-- When subscribed, matching notification will arrive as signals (see @{connd})
	-- @param connd a connection descriptor.
	-- @param subscrib_id a unique subscription id. If nil, a random one will be generated.
	-- @param filter an array contaning the subscription filter. Each entry in the array is a table
	-- containing 'attr', 'op' and 'value' fields describing an expression.
	-- @return _true_ on succes, _nil, err_ on failure
	-- @usage local rnr = bobot.wait_for_device('rnr_client')
	--rnr.subscribe( 'subscrib100', {
	--	{attrib='sensor', op='=', value='node1'},
	--	{attrib='temperature', op='>', value='30'},
	--})
	device.subscribe = function (connd, subscrib_id, filter) 
		subscrib_id = subscrib_id or tostring(math.random(2^30))
		local vlines={[1]='SUBSCRIBE', [2]='subscription_id='..subscrib_id, [3] = 'FILTER'}
		for _, r in ipairs(filter) do
			vlines[#vlines+1]= tostring(r.attrib) .. r.op .. tostring(r.value)
		end
		vlines[#vlines+1]= 'END\n'
		local s = table.concat(vlines, '\n')
		return connd.skt:send_sync(s)
	end

	--- Remove a Subscription.
	-- @param connd a connection descriptor.
	-- @param subscrib_id a unique subscription id.
	-- @return _true_ on succes, _nil, err_ on failure
	device.unsubscribe = function (connd, subscrib_id) 
		local s ='UNSUBSCRIBE\nsubscription_id='..subscrib_id.. '\nEND\n'
		return connd.skt:send_sync(s)
	end
	
	
	--- Emit a Notification.
	-- @param connd a connection descriptor.
	-- @param data a table with the data to be sent.
	-- @return _true_ on succes, _nil, err_ on failure
	-- @usage local rnr = bobot.wait_for_device('rnr_client')
	--rnr.subscribe( 'notif100', {sensor = 'node2', temperature = 25} )
	device.emit_notification = function (connd, data)
		data.notification_id = data.notification_id or tostring(math.random(2^30))
		local vlines={[1]='NOTIFICATION'}
		for k, v in pairs(data) do
			vlines[#vlines+1]= tostring(k) .. '=' .. tostring(v)
		end
		vlines[#vlines+1]= 'END\n'
		local s = table.concat(vlines, '\n')
		return connd.skt:send_sync(s)
	end
	
	log('RNRCLIENT', 'INFO', 'Device %s created: %s', device.module, device.name)
	toribio.add_device(device)
end

return M

--- Connection descriptor.
-- This table is populated by toribio from the configuration file.
-- @table connd
-- @field task task that will emit signals associated to this device.
-- @field events task that will emit signals associated to this device.
-- It is a table with a single field, `notification_arrival`,  a new notification has arrived.  
-- The first parameter of the signal is a table with the notification's content.

--- Configuration Table.
-- This table is populated by toribio from the configuration file.
-- @table conf
-- @field ip the ip where the Rnr agent listens (defaults to '127.0.0.1')
-- @field port the port where the Rnr agent listens (defaults to 8182)

