--luawa modules
local request, template = luawa.request, luawa.template

--tell the header we're a page
template:set( 'page', true )
template:set( 'page_title', request.args.title )

--simple load the template
template:load( 'core/header' )
template:load( 'page/' .. request.func )
template:load( 'core/footer' )