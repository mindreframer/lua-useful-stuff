--luawa modules
local request, user, database, template, header = luawa.request, luawa.user, luawa.database, luawa.template, luawa.header

--not logged in?
if not user:checkLogin() then return header:redirect( '/login' ) end

--get my data
local data = user:getData()
template:set( 'me', {
	id = data.id,
	name = data.name,
	email = data.email,
    private = data.private
} )
template:set( 'page', true )
template:set( 'page_title', 'Settings' )

--load templates
template:load( 'core/header' )
template:load( 'settings' )
template:load( 'core/footer' )