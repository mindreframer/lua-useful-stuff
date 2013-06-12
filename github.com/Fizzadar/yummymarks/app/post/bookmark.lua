--modules
local request, database, user, header, session = luawa.request, luawa.database, luawa.user, luawa.header, luawa.session

--logged in?
if not user:checkLogin() then return header:redirect( 'Location' ) end

--set referrer
request.referrer = request.referrer or '/'

--bookmark id not set?
if not request.post.bookmark_id then return header:redirect( request.referrer ) end

--unfavorite
if request.func == 'bookmark_unfavorite' then
	database:update(
		'bookmark',
		{ favorite = 0 },
		{ user_id = user:getData().id, id = request.post.bookmark_id }
	)
	return header:redirect( request.referrer )



--favorite
elseif request.func == 'bookmark_favorite' then
	database:update(
		'bookmark',
		{ favorite = 1 },
		{ user_id = user:getData().id, id = request.post.bookmark_id }
	)
	return header:redirect( request.referrer )



--uncollect
elseif request.func == 'bookmark_uncollect' then
	--collection must also be set
	if request.post.collection_id then
		local result = database:update(
			'bookmark',
			{ collection_id = 0, collection_name = '' },
			{ user_id = user:getData().id, id = request.post.bookmark_id }
		)
		if result then
			--take -1 from collections bookmarks
			request.post.collection_id = tonumber( request.post.collection_id )
			database:query( 'UPDATE collection SET bookmarks = bookmarks - 1 WHERE id = ' .. request.post.collection_id )
		end
		return header:redirect( request.referrer )
	end



--delete
elseif request.func == 'bookmark_delete' then
	database:delete(
		'bookmark',
		{ user_id = user:getData().id, id = request.post.bookmark_id }
	)
	return header:redirect( '/' )
end