--- RAN compatible monitoring service.
-- This task implements a rmoon service. It allows to monitor device attributes and signals.
-- @module ran_rmoon
-- @alias device

local M = {}

local toribio = require 'toribio'
local sched = require 'sched'
local log = require 'log'
local messages = require 'tasks/ran/messages'
local ran_util= require 'tasks/ran/util'

local configuration --holds conf after init()
local rnr --holds rnr connection after init()

local pep_commands = {
	get_mib = function (params)
		-- mib
		if params.mib then
			local mibis, mibdev, mibf = ran_util.get_mib_func(params.mib)
			if mibis == 'function' then
				local out=mibf(params)
				return {status = "ok", value=out}
			else
				return {status = "mib not supported"}
			end
		else
			log('PEP', 'WARN', 'malformed request "%s": no mib', tostring(params.notification_id))
			return {status = "malformed request"}
		end
	end,
	print = function (params)
		print( "PEP:", params.message)
	end
}

--- Initialize and starts the module.
-- This is called automatically by toribio if the _load_ attribute for the module in the configuration file is set to
-- true.
-- @param conf the configuration table (see @{conf}).
M.init = function(conf)
	configuration = conf
	conf.my_hostname = conf.my_hostname or 'host'..math.random(2^30)
	conf.my_servicename = conf.my_servicename or '/lupa/pep'
	
	rnr = toribio.wait_for_device('rnr_client').new_connection()
	
	local waitd_rnr = sched.new_waitd({
		emitter = rnr.task,
		events = {rnr.events.notification_arrival},
		buffer = 10,
	})
	sched.sigrun(waitd_rnr, function(_, _, notif)
		local command = notif.command
		
		if notif.message_type == 'action' and command then
			local response
			if pep_commands[command] then
				log('PEP', 'INFO', 'Incomming command "%s", id %s', tostring(command), tostring(notif.notification_id))
				response = pep_commands[command](notif)
				if response then
					local msg=messages.prepare_response(conf, notif, response)
					rnr:emit_notification(msg)
				end
			else
				log('PEP', 'WARN', 'Incomming unknown command "%s", id %s', tostring(command), tostring(notif.notification_id))
			end
		end
	end)
	
	--local subsn_rmoon = "SUBSCRIBE\nhost=".. configuration.my_host 
	--.."\nservice=".. configuration.my_name_rmoon .."\nsubscription_id=rmoon"..subsnid
	--.. "\nFILTER\ntarget_host=".. configuration.my_host .."\ntarget_service=".. configuration.my_name_rmoon .."\nEND\n"
	local filter = {
		{attrib='target_host', op= '=', value=conf.my_hostname},
		{attrib='target_service', op= '=', value=conf.my_servicename},
	}
	rnr:subscribe( "pep_sub_"..tostring(math.random(2^30)), filter )
	log('PEP', 'INFO', 'Task started as host %s, service %s', tostring(conf.my_hostname), tostring(conf.my_servicename))
	
	---[[
	-- Sample device:
	local sample_mib = {
		name = 'mib1', 
		module = 'mib1', 
		events = {tick='E'},
		task = sched.run(function()
			while true do
				sched.sleep(1)
				sched.signal('E', sched.get_time())
			end
		end),
		random = function() return math.random() end,
		time = function() return sched.get_time() end
	}
	log('PEP', 'INFO', 'Device %s created: %s', sample_mib.module, sample_mib.name)
	toribio.add_device(sample_mib)
	--]]
end

return M

--- Configuration Table.
-- This table is populated by toribio from the configuration file.
-- @table conf
-- @field my_hostname the unique name for the host in the rnr network
-- @field my_servicename defaults to 'lupa/rmoon', and usually should not be changed

