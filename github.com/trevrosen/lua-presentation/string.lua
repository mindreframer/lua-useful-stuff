-- A couple basic string functions

-- string.format
-- works like C's printf
-- http://www.cplusplus.com/reference/clibrary/cstdio/printf/

local friend, foe = "Jorge", "Eduardo"
print(string.format("I saved %s by hitting %s with the Godly Axe of Frost", friend, foe))

-- string.match
-- takes a string and a pattern to search for
-- patterns in Lua are NOT PCRE or POSIX regex
-- they are closer to an 80/20 solution for pattern matching than a full regex engine

local rufus_string = "Bill and Ted travel through time with Rufus"
if string.match(rufus_string, "[R|r]ufus") then
  print "Rufus is in the house" -- you can call print with string literals w/out parens
end
