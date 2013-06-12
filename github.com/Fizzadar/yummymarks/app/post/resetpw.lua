--modules
local request, user, header, template, email = luawa.request, luawa.user, luawa.header, luawa.template, luawa.email

--reset password, get key
local key, err = user:resetPassword( request.post.email )
if key then
    --send email
    email:send( request.post.email, 'Password Reset', 'Please click: http://' .. luawa.hostname .. ':8084/resetpw_login?email=' .. request.post.email .. '&key=' .. key )

    --user
	template:set( 'info', 'An email has been sent to you containing further instructions.' )
else
	template:set( 'error' , err )
end

--load resetpw page
request.func = 'reset_pw'

return luawa:processFile( 'app/get/page' )