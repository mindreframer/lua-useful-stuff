--json for bookmark tags
local json = require( 'cjson.safe' )

--luawa modules
local request, user, database, template, header = luawa.request, luawa.user, luawa.database, luawa.template, luawa.header

--not logged in?
if not user:checkLogin() then return header:setHeader( 'Location', '/login' ) end


--one tag
if request.get.tag_id then
	--get tag (dont add yet)
	local tag = database:select(
		'tag', '*',
		{ id = request.get.tag_id },
		'id DESC', 1
	)

	--make sure its a number for raw query
	request.get.tag_id = tonumber( request.get.tag_id )
	--direct query
	local bookmarks = database:query( [[
		SELECT bookmark.* FROM bookmark, bookmark_tags WHERE
		bookmark_tags.bookmark_id = bookmark.id
		AND bookmark.user_id = ]] .. user:getData().id .. [[
		AND bookmark_tags.tag_id = ]] .. request.get.tag_id
	)
	--loop favorites
	for k, bookmark in pairs( bookmarks ) do
		--strip http from base_url & make collection_id a number
		bookmark.favicon_url = bookmark.base_url:gsub( 'http://', '' )
		bookmark.collection_id = tonumber( bookmark.collection_id )

		--split bookmarks
		bookmark.tag_list = json.decode( bookmark.tags )
	end
	if bookmarks and #bookmarks > 0 then template:set( 'bookmarks', bookmarks ) end

	--edit + add
	if tag and #tag > 0 then
		template:set( 'page_title', 'Tag / ' .. tag[1].name )

		tag[1].bookmarks = #bookmarks --count bookmarks
		template:set( 'tag', tag[1] )
	end

	template:load( 'core/header' )
	template:load( 'tag' )
	template:load( 'core/footer' )


--all tags
else
	--get all our bookmarks
	local bookmarks = database:select(
		'bookmark', '*',
		{ user_id = user:getData().id },
		'time DESC'
	)
	--work out tags from bookmarks
	local tags = {}
	local count = 0
	for k, bookmark in pairs( bookmarks ) do
		local t = json.decode( bookmark.tags )
		for c, tag in pairs( t ) do
			if not tags[tag.name] then
				tags[tag.name] = { name = tag.name, id = tag.id, bookmarks = 1 }
			else
				tags[tag.name].bookmarks = tags[tag.name].bookmarks + 1
			end
			count = count + 1
		end
	end
	if count > 0 then template:set( 'tags', tags ) end

	--title
	template:set( 'page_title', 'Tags' )

	--load templates
	template:load( 'core/header' )
	template:load( 'tags' )
	template:load( 'core/footer' )
end