local M = {}

local sched = require 'sched'

--Provides a counter function
local function newCounter ()
	local i = 0
	return function ()   -- anonymous function
		i = i + 1
		return i
	end
end

local response_counter = newCounter()
local trap_counter = newCounter()

M.prepare_response = function (conf, reply_to, data)
	data.message_type = 'response'
	data.notification_id = data.notification_id or  conf.my_hostname .. "_resp_" .. response_counter() 
	data.host = conf.my_hostname
	data.service = conf.my_servicename
	data.timestamp = sched.get_time()
	data.target_host = reply_to.host
	data.target_service = reply_to.service
	data.reply_to = reply_to.notification_id
	
	return data
end

M.prepare_trap = function (conf, watcher, data)
	data.message_type = 'trap'
	data.notification_id = data.notification_id or  conf.my_hostname .. "_trap_" .. trap_counter() 
	data.host = conf.my_hostname
	data.service = conf.my_servicename
	data.timestamp = sched.get_time()
	data.target_host = watcher.host
	data.target_service = watcher.service
	data.watcher_id = watcher.watcher_id
	
	return data
end


return M
