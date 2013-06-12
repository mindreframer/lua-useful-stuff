local M = {}

M.start = function(conf)
	local filename = assert(conf.filename)
	f = io.open(filename, 'r')
	local devicename='urandom:' .. filename
	local api = {
		get_byte = { 
			call = function ()
				local t = f:read(1)
				return string.byte(t)
			end,
			parameters = {},
			returns = {
				[1]={rname="random_byte", rtype="number"}
			},
		},
	}
	
	local device={
		name=devicename, 
		module='urandom',
		api=api, 
		filename=filename
	}

	toribio.add_device(device)
end

return M
