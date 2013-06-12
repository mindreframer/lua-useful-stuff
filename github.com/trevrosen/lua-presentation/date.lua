-- Date and time functions
-- http://www.lua.org/pil/22.1.html


-- Unix epoch date
print "Get a UNIX epoch date:\n"
print(os.time())

print "\nCreate a time table (literally):\n"
-- Getting friendlier dates involves creating a table
local table_of_the_now = os.date("*t", os.time())

-- the table of date/time stuff
for k,v in pairs(table_of_the_now) do
  print(k,v)
end

print "\nOr you can just use a format string:\n"

print(os.date("Today is %A, %m %d, %Y"))



