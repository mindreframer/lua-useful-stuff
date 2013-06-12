-- The "table" is the compound data structure of Lua.
-- They have properties of both hashes and arrays in Ruby.
-- The syntax looks a lot like Javascript objects

foo = {
  name = "A glorious Foo" -- "name" looks like an declared variable, but acts as a table key
}

foo.bar = "bar string, yo"

-- indices w/out keys are indexed contiguously
bar = {
  "another string", -- index 1
  name = bar, -- index "name" (but not 2!)
  "yet another string",-- index 2
}

print(foo)     -- gives the memory address
print(foo.name) -- gives the string we put at that key
print(foo.bar) -- gives the string we put at that key

print(bar[1]) -- arrays start w/ 1 in Lua(!)   (( http://www.luafaq.org/index.html#T1.5.1 ))
