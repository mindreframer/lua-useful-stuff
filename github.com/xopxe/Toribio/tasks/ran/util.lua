local M = {}

local toribio = require 'toribio'

M.get_mib_func = function (mib)
	local entry = toribio.devices
	local n = 1
	local tokens = {}
	local device
	for token in string.gmatch(mib, "[^%.]+") do
		tokens[#tokens+1]=token
		entry = entry[token]
		if not entry then
			return nil, 'unknown mib "' .. tostring(mib)..'", failed at level ' .. n
		end
		if n==1 then device=entry end
		n = n+1
	end
	--print ('>>>>>>', tokens[#tokens-1], entry)
	if tokens[#tokens-1]=='events' then
		return 'event', device, entry
	else
		if type(entry) == 'function' then
			return 'function', device, entry
		end
	end
	return nil, 'malformed mib "' .. tostring(mib)..'", not a function nor event'
end

return M
