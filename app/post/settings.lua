--modules
local user, request, header, template = luawa.user, luawa.request, luawa.header, luawa.template

--logged in?
if not user:checkLogin() then return header:redirect( '/login' ) end

--invalid email (weak check)
if not request.post.email:find( '^[^@]+@' ) then
	template:set( 'error', 'please use a valid email address' )
else
	--private?
	local private = 0
	if request.post.private then private = 1 end

	--update settings
	local status, err = user:setData( { email = request.post.email, name = request.post.name, password = request.post.password, private = private } )
	if status then
		template:set( 'success', 'Settings updated' )
	else
		if err:find( 'Duplicate' ) then
			template:set( 'error', 'this email is already in use by another user' )
		else
			template:set( 'error', err )
		end
	end
end

--back to settings
request.func = 'settings'
luawa:processFile( 'app/get/settings' )