--modules
local request, user, header, template, session = luawa.request, luawa.user, luawa.header, luawa.template, luawa.session


local status, err = true, ''

--check token
if not session:checkToken( request.post.token ) then
    status = false
    err = 'Invalid token'
else
    --login user
    status, err = user:login( request.post.email, request.post.password )
    if status then
    	--redirect
    	return header:redirect( '/' )
    end
end

--login failed
err = err or 'Invalid username or password'
template:set( 'error', err )

--login page
request.func = 'login'
request.args.title = 'Login'
luawa:processFile( 'app/get/page' )