local M = {}

M.init = function(conf)
	local http_server = require "tasks/http-server"
	local slt2 = require 'tasks/wbctrl/slt2'
	local tohtml = require 'tasks/wbctrl/tohtml'
	local stream = require 'stream'
	
	--http_server.serve_static_content_from_ram('/', '../tasks/http-server/www')
	--http_server.serve_static_content_from_stream('/docs/', '../docs')

	local tmpl = slt2.loadstring([[
	<html>
	<head>
	<title>Toribio</title>
	</head>
	<body>
	<h1>Toribio</h1>
	<hr>
	Using memory: #{= string.format('%.2f', mem) }kb
	<hr>
	<p>Copyright (c) 2012 Jorge Visca<jvisca@fing.edu.uy>, MINA Group, 
	    Facultad de Ingenier&iacute;a, Universidad de la Rep&uacute;blica del Uruguay.</p>
	</body>
	</html>
	]])
	
	http_server.set_request_handler('GET', '/', function(method, path, http_params, http_header)
		local out = slt2.render(tmpl, {mem = collectgarbage('count')})
		return 200, {['Content-Type']='text/html'}, out
	end)
	
	http_server.set_request_handler('GET', '/dump/', function(method, path, http_params, http_header)
		local str = stream.new()
		--local obj = _G[http_params.obj or '_G']
		local obj = (require 'toribio')
		tohtml.object_to_html(obj, function(s) 
			--print (s)
			str:write(s) 
		end)
		return 200, {['Content-Type']='text/html'}, str
	end)
	
	
	http_server.init(conf)
end

return M