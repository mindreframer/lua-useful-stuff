--json for bookmark tags
local json = require( 'cjson.safe' )

--luawa modules
local request, user, database, template, header, session = luawa.request, luawa.user, luawa.database, luawa.template, luawa.header, luawa.session

--not logged in?
if not user:checkLogin() then return header:setHeader( 'Location', '/login' ) end

--token
template:set( 'token', session:getToken() )

--one collection
if request.get.collection_id then
	--get collection
	local collection = database:select(
		'collection', '*',
		{ user_id = user:getData().id, id = request.get.collection_id },
		'id DESC', 1
	)
--SHOULD be if not collection[1] then return 404

	if collection and #collection > 0 then
		template:set( 'page_title', 'Collections / ' .. collection[1].name )
		template:set( 'collection', collection[1] )
	end

	--get bookmarks
	local bookmarks = database:select(
		'bookmark', '*',
		{ user_id = user:getData().id, collection_id = request.get.collection_id },
		'time DESC'
	)
	if bookmarks and #bookmarks > 0 then
		for k, bookmark in pairs( bookmarks ) do
			--strip http from base_url & make collection_id a number
			bookmark.favicon_url = bookmark.base_url:gsub( 'http://', '' )

			--split bookmarks
			bookmark.tag_list = json.decode( bookmark.tags )
		end
	end
	template:set( 'bookmarks', bookmarks )

	--load templates
	template:load( 'core/header' )
	template:load( 'collection' )
	template:load( 'core/footer' )



--all collections
else
	--get collections
	local collections = database:select(
		'collection', '*',
		{ user_id = user:getData().id },
		'time DESC'
	)
	if collections and #collections > 0 then template:set( 'collections', collections ) end

	--title
	template:set( 'page_title', 'Collections' )

	--load templates
	template:load( 'core/header' )
	template:load( 'collections' )
	template:load( 'core/footer' )
end