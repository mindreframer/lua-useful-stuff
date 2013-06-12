--modules
local request, user, header, template = luawa.request, luawa.user, luawa.header, luawa.template

--invalid email? pw not = password
if request.post.email:find( '^[^@]+@' ) then
	--register user
	local register, err = user:register( request.post.email, request.post.password, request.post.name )

	--work?
	if register then
		--success
		template:set( 'success', 'Welcome to yummymarks, please login below' )
		--end with login
		request.func = 'login'
		return luawa:processFile( 'app/get/page' )
	else
		--register failed
		if err:find( 'Duplicate' ) then
			template:set( 'error', 'This email is already in use by another member!' )
		else
			template:set( 'error', 'Error when joining, please try again later' )
		end
	end
else
	template:set( 'error', 'Please use a valid email address' )
end

--login page
request.func = 'join'
luawa:processFile( 'app/get/page' )