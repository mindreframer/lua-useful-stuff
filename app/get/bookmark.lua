--local optimization!
local pairs = pairs
local tonumber = tonumber
local table = table
--json for bookmark tags
local json = require( 'cjson.safe' )

--luawa modules
local request, user, database, template, header, utils, session = luawa.request, luawa.user, luawa.database, luawa.template, luawa.header, luawa.utils, luawa.session

--not logged in? cya!
if not user:checkLogin() then
	request.func = 'home'
	return luawa:processFile( 'app/get/page' )
end

--token
template:set( 'token', session:getToken() )



--add bookmark page
if request.func == 'bookmark_add' then
	template:set( 'page_title', 'Add Bookmark' )
	template:set( 'page', true )
	template:load( 'core/header' )
	template:load( 'bookmark_add' )
	template:load( 'core/footer' )



--individual bookmark
elseif request.get.bookmark_id then
	--load bookmark
	local bookmark = database:select(
		'bookmark', '*',
		{ user_id = user:getData().id, id = request.get.bookmark_id },
		'id DESC', 1
	)
	if #bookmark == 1 then
		bookmark = bookmark[1]

		--split bookmarks
		bookmark.tag_list = json.decode( bookmark.tags )
		--rebuild bookmark list as string
		local tag_string = ''
		for k, v in pairs( bookmark.tag_list ) do
			tag_string = v.name .. ', ' .. tag_string
		end
		bookmark.tag_string = utils:rtrim( tag_string, ', ' )
		template:set( 'bookmark', bookmark )
		template:set( 'page_title', 'Bookmark / ' .. bookmark.title )
	end

	template:load( 'core/header' )
	template:load( 'bookmark' )
	template:load( 'core/footer' )



--bookmark browsing
else
	--paging
	request.get.page = request.get.page or 0
	--pageing on template
	template:set( 'page_number', request.get.page  )
	template:set( 'page_number_prev', request.get.page - 1 )
	template:set( 'page_number_next', request.get.page + 1 )

	--get all favorite bookmarks, sort by date, set to template
	local favorites = database:select(
		'bookmark', '*',
		{ user_id = user:getData().id, favorite = 1 },
		'time DESC'
	)
	if favorites and #favorites > 0 then
		--loop favorites
		for k, bookmark in pairs( favorites ) do
			bookmark.collection_id = tonumber( bookmark.collection_id )

			--split bookmarks
			bookmark.tag_list = json.decode( bookmark.tags )
		end

		--add to template
		template:set( 'favorites', favorites )
	end

	--get 30 other bookmarks
	local bookmarks = database:select(
		'bookmark', '*',
		{ user_id = user:getData().id, favorite = 0 },
		'time DESC', 30, request.get.page * 30
	)
	--bookmark collection bit
	if bookmarks and #bookmarks > 0 then
		--map collections => bookmark_ids
		local collection_to_bookmark = {}

		--loop bookmarks
		for k, bookmark in pairs( bookmarks ) do
			bookmark.collection_id = tonumber( bookmark.collection_id )

			--split bookmarks
			bookmark.tag_list = json.decode( bookmark.tags )

			--if we're a collection but there's no collection already
			if bookmark.collection_id > 0 and not collection_to_bookmark[bookmark.collection_id] then
				local tmp = bookmark
				bookmarks[k] = { type = 'collection', id = tmp.collection_id, name = tmp.collection_name, bookmarks = { tmp } }
				collection_to_bookmark[bookmark.collection_id] = k
			--if we're a collection and there's already one
			elseif bookmark.collection_id > 0 then
				table.insert( bookmarks[collection_to_bookmark[bookmark.collection_id]].bookmarks, bookmark )
				bookmarks[k] = nil
			end
		end

		--add to template
		template:set( 'bookmarks', bookmarks )
	end

	--title
	template:set( 'page_title', 'Bookmarks' )

	--load templates
	template:load( 'core/header' )
	template:load( 'bookmarks' )
	template:load( 'core/footer' )
end