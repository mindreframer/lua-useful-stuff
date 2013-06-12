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
--local rmoon = require 'ran/rmoon'

local configuration --holds conf after init()
local rnr --holds rnr connection after init()

--list of set-up watchers
--{watcher_id=taskd}
local environment_trackers = {}


--returns inrange,mustemit
local function in_out_range(in_range, evval, op, value, hysteresis)
	local evval_n, value_n=tonumber(evval), tonumber(value)
	--print ("==",in_range,mib, evval..op..value, evval_n, value_n,tostring(evval==value), tostring(evval_n==value_n), hysteresis)
			
	if in_range then
		if ((not evval_n or not value_n ) and 
				op=="=" and evval~=value) 
			or
			(evval_n and value_n and ( 
				(op=="=" and (evval_n<value_n-hysteresis or evval_n>value_n+hysteresis)) or
				(op==">" and evval_n<value_n-hysteresis) or
				(op=="<" and evval_n>value_n+hysteresis))) 
		then
			--exiting range, don't return anything
			--print ("saliendo")
			return false, nil
		else
			--stay in range, don't return anything
			--print ("dentro")
			return true, nil
		end
	else
		--print ("##"..evval..op..value.."##")
		if (op=="=" and evval==value) or
			(evval_n and value_n and ( 
				(op=="=" and evval_n==value_n) or
				(op==">" and evval_n>value_n) or
				(op=="<" and evval_n<value_n))) 
		then
			--entering range, return value
			--print ("entrando")
			--print ("SE CUMPLE QUE : ", evval_n, op, value_n)
			return true, evval_n

		else
			--staying out of range, don't return anything
			--print ("NO SE CUMPLE QUE : ", evval_n, op, value_n)
			return false, nil
		end
	end
end


local function value_tracker (mibis, mibdev, mibf, params)
	local mib, op, value, hysteresis, timeout, interval = 
		params.mib, params.op, params.value, tonumber(params.hysteresis) or 0, 
		tonumber(params.timeout) or math.huge, tonumber(params.interval) or 1

print ("---value", mibis, mib, op, value, hysteresis, timeout, interval)

	local getter
	if mibis=='function' then
		getter = function()
			sched.sleep(interval)
			local evval = mibf(params)
			return evval
		end
	elseif mibis=='event' then
		local waitd = {
			emitter = mibdev.task,
			events = {mibf},
		}
		getter  = function()
			local _, _, evval = sched.wait(waitd)
			return evval
		end
	else
		error()
	end

	local in_range,ret=false
	local ts=sched.get_time()
	while true do
		local evval = getter()
		
		in_range, ret = in_out_range(in_range, evval, op, value, hysteresis)
		local time=sched.get_time()
		if ret or (time-ts > timeout) then
			ts=time
			local trap = messages.prepare_trap(configuration, params, {
				mib=mib, 
				value=ret,
			})
			rnr:emit_notification(trap)
		end
	end
end
local function delta_tracker (mibis, mibdev, mibf, params)
	local mib, op, delta, hysteresis, timeout, interval = 
		params.mib, params.op, tonumber(params.delta) or 0, tonumber(params.hysteresis) or 0, 
		tonumber(params.timeout) or math.huge, tonumber(params.interval) or 1

print ("---delta", mib, op, delta, hysteresis, timeout)

	local getter
	if mibis=='function' then
		getter = function()
			sched.sleep(interval)
			local evval = mibf(params)
			return evval
		end
	elseif mibis=='event' then
		local waitd = {
			emitter = mibdev.task,
			events = {mibf},
		}
		getter  = function()
			local _, _, evval = sched.wait(waitd)
			return evval
		end
	else
		error()
	end

	local in_range,ret=false
	local last_evval
	local ts=sched.get_time()
	while true do
		local evval = getter()
		
		local delta_evval = evval - (last_evval or evval)
		last_evval=evval
		
		in_range, ret = in_out_range(in_range, delta_evval, op, delta, hysteresis)
		--print("$$$ Ret : ", ret)
		local time=sched.get_time()
		if ret or (time-ts > timeout) then
			ts=time
			local trap = messages.prepare_trap(configuration, params, {
				mib=mib, 
				value=ret,
			})
			rnr:emit_notification(trap)
		end
	end
end
local function delta_e_tracker (mibis, mibdev, mibf, params)
	local mib, op, delta_e, hysteresis, timeout, interval = 
		params.mib, params.op, tonumber(params.delta_e) or 0, tonumber(params.hysteresis) or 0, 
		tonumber(params.timeout) or math.huge, tonumber(params.interval) or 1

	print ("---delta_e", mib, op, delta_e, hysteresis, timeout)
	
	local getter
	if mibis=='function' then
		getter = function()
			sched.sleep(interval)
			local evval = mibf(params)
			return evval
		end
	elseif mibis=='event' then
		local waitd = {
			emitter = mibdev.task,
			events = {mibf},
		}
		getter  = function()
			local _, _, evval = sched.wait(waitd)
			return evval
		end
	else
		error()
	end

	local in_range,ret=false
	local last_e_evval
	local ts=sched.get_time()

	local evval = getter() or 0
	last_e_evval=evval

	while true do
		evval = getter() or 0
		
		local delta_e_evval = evval - last_e_evval
		
		in_range, ret = in_out_range(in_range, delta_e_evval, op, delta_e, hysteresis)
		local time=sched.get_time()
		if ret or (time-ts > timeout) then
			ts=time
			last_e_evval=evval
			local trap = messages.prepare_trap(configuration, params, {
				mib=mib, 
				value=ret,
			})
			rnr:emit_notification(trap)
		end
	end
end


local function register_watcher(mibis, mibdev, mibf, params)
	--local mib, op, value, histeresis = params.mib, params.op, params.value, params.hysteresis or 0
	
	local watcher_id = params.watcher_id
	
	local task
	if params.value then
		task = sched.run( value_tracker, mibis, mibdev, mibf, params)
	elseif params.delta then
		task = sched.run( delta_tracker, mibis, mibdev, mibf, params)
	elseif params.delta_e then
		task = sched.run( delta_e_tracker, mibis, mibdev, mibf, params)
	else
		return nil, "malformed watcher request"
	end
	environment_trackers[watcher_id]=task
	
	return watcher_id
end

local rmoon_commands = {
	watch_mib = function (params)
		--local mib, op, value, histeresis = params.mib, params.op, params.value, params.hysteresis or 0
		
		if params.mib then
			local mibis, mibdev, mibf = ran_util.get_mib_func(params.mib)
			if mibis then
				local wid, err = register_watcher(mibis, mibdev, mibf, params)
				if wid then
					return {status = "ok", watcher_id=wid}
				else
					log('RMOON', 'WARN', 'monitoring failed with "%s"', tostring(err)) 
					return {status = err}
				end
			else
				log('RMOON', 'WARN', tostring(mibdev)) 
				return {status = "mib not supported"}
			end
		elseif params.event then
			local devicename, eventname = string.match(params.event, '^([^%.]+)%.([^%.]+)$')
			local device = toribio.devices[devicename]
			if not device then
				log('RMOON', 'WARN', 'device "%s" not found', tostring(devicename)) 
				return {status = "device not found"}
			end
			local taskd, err = toribio.register_callback(device, eventname, function(data)
				local trap = messages.prepare_trap(configuration, params, {
					event=params.event, 
					value=tostring(data),
				})
				rnr:emit_notification(trap)
			end)
			if not taskd then 
				log('RMOON', 'WARN', 'monitoring failed with "%s"', tostring(err)) 
				return {status = tostring(err)}
			end
			environment_trackers[params.watcher_id] = taskd
			return {status = "ok", watcher_id=params.watcher_id}
		else
			log('RMOON', 'WARN', 'malformed request "%s": no mib nor event specified', tostring(params.watcher_id))
			return {status = "malformed request"}
		end
	end,
	remove_watcher = function (params)
		local wid=params.watcher_id
		if wid and environment_trackers[wid] then
			environment_trackers[wid]:kill()
			environment_trackers[wid]=nil
			return {status = "ok", watcher_id=wid}
		end
	end
}

--- Initialize and starts the module.
-- This is called automatically by toribio if the _load_ attribute for the module in the configuration file is set to
-- true.
-- @param conf the configuration table (see @{conf}).
M.init = function(conf)
	configuration = conf
	conf.my_hostname = conf.my_hostname or 'host'..math.random(2^30)
	conf.my_servicename = conf.my_servicename or '/lupa/rmoon'
	
	rnr = toribio.wait_for_device('rnr_client').new_connection()
	local watcher_count = 0
	
	local waitd_rnr = sched.new_waitd({
		emitter = rnr.task,
		events = {rnr.events.notification_arrival},
		buffer = 10,
	})
	sched.sigrun(waitd_rnr, function(_, _, notif)
		local command = notif.command
		watcher_count  = watcher_count +1
		notif.watcher_id = notif.watcher_id or conf.my_hostname .. '_watcher_'..watcher_count
		
		if notif.message_type == 'action' and command then
			local response
			if rmoon_commands[command] then
				log('RMOON', 'INFO', 'Incomming command "%s", wid %s', tostring(command), tostring(notif.watcher_id))
				response = rmoon_commands[command](notif)
				if response then
					local msg=messages.prepare_response(conf, notif, response)
					rnr:emit_notification(msg)
				end
			else
				log('RMOON', 'WARN', 'Incomming unknown command "%s", wid %s', tostring(command), tostring(notif.watcher_id))
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
	rnr:subscribe( "rmoon_sub_"..tostring(math.random(2^30)), filter )
	log('RMOON', 'INFO', 'Task started as host %s, service %s', tostring(conf.my_hostname), tostring(conf.my_servicename))
	
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
	log('RMOON', 'INFO', 'Device %s created: %s', sample_mib.module, sample_mib.name)
	toribio.add_device(sample_mib)
	--]]
end

return M

--- Configuration Table.
-- This table is populated by toribio from the configuration file.
-- @table conf
-- @field my_hostname the unique name for the host in the rnr network
-- @field my_servicename defaults to 'lupa/rmoon', and usually should not be changed

