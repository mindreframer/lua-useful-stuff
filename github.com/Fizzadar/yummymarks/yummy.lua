local root = '/Users/Fizzadar/Dropbox/Oxygem/Webroot/yummymarks/new/src-lua_nginx/'

--get luawa globally
luawa = require( root .. 'luawa/core' )
--set luawa root & config file from our file
luawa:setConfig( root, 'config' )


--add a functions to luawa
--time ago
function luawa.template:timeAgo( time )
	local ago = os.time() - time

	if ago < 0 then
		return 'future'
	elseif ago < 60 then
		return ago .. 's'
	elseif ago < 3600 then
		return math.floor( ago / 60 ) .. 'm'
	elseif ago < 3600 * 24 then
		return math.floor( ago / 3600 ) .. 'h'
	elseif ago < 3600 * 24 * 7 then
		return math.floor( ago / 3600 * 24 ) .. 'd'
	else
		return math.floor( ago / ( 3600 * 24 * 7 ) ) .. 'w'
	end
end


--pass request to luawa
luawa:run()