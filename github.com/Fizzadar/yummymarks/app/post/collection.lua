--modules
local request, database, user, header = luawa.request, luawa.database, luawa.user, luawa.header

--logged in?
if not user:checkLogin() then return header( 'Location', '/' ) end

--set referrer
request.referrer = request.referrer or '/'

--collection id not set?
if not request.post.collection_id then return header:redirect( request.referrer ) end

--delete
if request.func == 'collection_delete' then
	--delete collection
	local result = database:delete(
		'collection',
		{ user_id = user:getData().id, id = request.post.collection_id }
	)
	if result then
		--remove collection from bookmarks
		database:update(
			'bookmark',
			{ collection_id = 0, collection_name = '' },
			{ user_id = user:getData().id, collection_id = request.post.collection_id }
		)
	end
	return header:redirect( '/collections' )
end