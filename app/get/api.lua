--luawa modules
local request, template, user, utils, database = luawa.request, luawa.template, luawa.user, luawa.utils, luawa.database

--must be logged in, get.url must also be set
if template.api and user:checkLogin() and request.get.url then
	--try to get bookmark
	local result = database:select(
		'bookmark', 'id',
		{ user_id = user:getData().id, url = request.get.url },
		'id DESC', 1
	)
	if #result == 1 then
		return template:add( 'bookmarked', true )
	end
end

--still here?
return template:add( 'bookmarked', false )