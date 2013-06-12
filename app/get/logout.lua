--modules
local user, header = luawa.user, luawa.header

--logout
user:logout()

--redirect
header:redirect( '/' )