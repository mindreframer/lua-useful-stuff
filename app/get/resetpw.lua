local request, template, user = luawa.request, luawa.template, luawa.user


local status, err = user:resetPasswordLogin( request.get.email, request.get.key )

if status then
    --set message
    template:set( 'success', 'You have logged in via email! Please change your password below' )

    return luawa:processFile( 'app/get/settings' )
else
    --fail
    template:set( 'error', err )
    request.func = 'reset_pw'
    return luawa:processFile( 'app/get/page' )
end