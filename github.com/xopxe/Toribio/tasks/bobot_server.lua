local M = {}

local toribio = require 'toribio'
local devices = toribio.devices
local sched = require "sched"
local bobot = nil --require('comms/bobot').bobot
local log = require 'log'

table.pack=table.pack or function (...)
	return {n=select('#',...),...}
end

local function split_words(s)
	local words={}

	for p in string.gmatch(s, "%S+") do
		words[#words+1]=p
	end
	
	return words
end

local process = {}

process["INIT"] = function () --to check the new state of hardware on the fly
	--server_init()
	toribio.init(nil)
	return 'ok'
end
process["REFRESH"] = function () --to check the new state of hardware on the fly
	--server_refresh()
	sched.signal('do_bobot_refresh')
	return 'ok'
end


process["LIST"] = function ()
	local ret,comma = "", ""
	for name, _ in pairs(devices) do
		ret = ret .. comma .. name
		comma=","
	end
	return ret
end

--[[
process["LISTI"] = function ()
    if baseboards then
        for _, bb in ipairs(bobot.baseboards) do
    	    local handler_size=bb:get_handler_size()
            for i=1, handler_size do
                t_handler = bb:get_handler_type(i)
            end
        end
    end
end
--]]

process["OPEN"] = function (parameters)
	local d  = parameters[2]
	local ep1= tonumber(parameters[3])
	local ep2= tonumber(parameters[4])

	if not d then
		log('BOBOTSRV', 'ERROR', "ls:Missing 'device' parameter")
		return
	end

	return "ok"

end
process["DESCRIBE"] = function (parameters)
	local d  = parameters[2]
	local ep1= tonumber(parameters[3])
	local ep2= tonumber(parameters[4])

	if not d then
		log ('BOBOTSRV', 'ERROR', "ls:Missing \"device\" parameter")
		return
	end
	
	local device = devices[d]

	--if not device.api then
	--	return "missing driver"
	--end

	local  skip_fields = {remove=true, name=true, register_callback=true, events=true,
		task=true, filename=true, module=true, bobot_metadata=true}
	
	local ret = "{"
	for fname, fdef in pairs(device) do
			if not skip_fields[fname] then 
			ret = ret .. fname .. "={"
			ret = ret .. " parameters={"
			local bobot_metadata = ((device.bobot_metadata or {})[fdef] or {
				parameters={}, returns={}
			})
			local meta_parameters = bobot_metadata.parameters
			for i,pars in ipairs(meta_parameters) do
				ret = ret .. "[" ..i.."]={"
				for k, v in pairs(pars) do
					ret = ret .."['".. k .."']='"..tostring(v).."',"
				end
				ret = ret .. "},"
			end
			ret = ret .. "}, returns={"
			local meta_returns = bobot_metadata.returns
			for i,rets in ipairs(meta_returns) do
				ret = ret .. "[" ..i.."]={"
				for k, v in pairs(rets) do
					ret = ret .."['".. k .."']='"..tostring(v).."',"
				end
				ret = ret .. "},"
			end
			ret = ret .. "}}," 
		end
	end
	ret=ret.."}"

	return ret
end
process["CALL"] = function (parameters)
	local d  = parameters[2]
	local call  = parameters[3]

	if not (d and call) then
		log ('BOBOTSRV', 'ERROR', "ls:Missing parameters %s %s", d, call)
		return
	end

	local device = devices[d]
	
	local api_call=device[call];
	if not api_call then return "missing call" end
	
	--local tini=socket.gettime()
	--local ok, ret = pcall (api_call.call, unpack(parameters,4))
	--if not ok then print ("Error calling", ret) end
	
	local ret = table.pack(pcall (api_call, unpack(parameters,4)))
	local ok = ret[1]
	if ok then 
		return table.concat(ret, ',', 2)
	else 
		print ("error calling", table.concat(ret, ',', 2))
	end
end
process["CLOSEALL"] = function ()
	if bobot and bobot.baseboards then
		for _, bb in ipairs(bobot.baseboards) do
            --this command closes all the open user modules
            --it does not have sense with plug and play
			bb:force_close_all() --modif andrew
		end
	end
	return "ok"
end
process["BOOTLOADER"] = function ()
	if bobot and bobot.baseboards then
		for _, bb in ipairs(bobot.baseboards) do
			bb:switch_to_bootloader()
		end
	end
	return "ok"
end

process["QUIT"] = function () 
	log ('BOBOTSRV', 'INFO', "Requested EXIT...")
	os.exit()
	return "ok"
end


M.init = function(conf)
	local selector = require 'tasks/selector'
	
	local ip = conf.ip or '127.0.0.1'
	local port = conf.port or 2009
	
	
	local tcprecv = selector.new_tcp_server(ip, port, 'line',  function( inskt, line, err)
		--print("bobot server:", inskt, line, err or '')
		if not line then return end
		local words=split_words(line)
		local command=words[1]
		if not command then
			log ('BOBOTSRV', 'ERROR', "bs:Error parsing line %s", line)
		else
			if not process[command] then
				log ('BOBOTSRV', 'ERROR', "bs:Command '%s' not supported:", command)
			else
				local ret = process[command](words) or ""
				if ret then 
					inskt:send(ret.."\n")
				else
					log ('BOBOTSRV', 'ERROR', "Error calling '%s'", command)
					inskt:send("\n")
				end
			end
		end
		return true
	end)
	
end

return M
