-- As in Ruby, iterators are very important to Lua.
-- Lua's notion of "iterator" is an abuse of the term, similar to Java.
-- What's actually happening in an iterator is similar to Ruby 1.9's Enumerator class,
-- which implements entities similar to the Lua functions described below.

-- These are formally best described as "generators"  http://en.wikipedia.org/wiki/Generator_(computer_programming)


-- First we will set up some tables to work with in the following examples.
-- The first table acts as an array of integers (and therefore has implied integer indices)
-- The second table has string keys.
local example_table = {10, 20, 30, 40, 50}
local example_table2 = {
  food = "feijoãda",
  drink = "Antarctica Guarana soda",
  fun   = "go-karts"
}


print "-----------------------------------------------------------"

print "Use pairs() to print indices and their values..."
for k,v in pairs(example_table) do 
  print(k,v) 
end

print "-----------------------------------------------------------"

print "Or key-value pairs:"
for k,v in pairs(example_table2) do 
  print(k,v) 
end

print "-----------------------------------------------------------"

print "ipairs() is similar, but works only on tables that have integer indices:"
for i,v in ipairs(example_table) do 
  print(i,v) 
end -- => outputs implied indices

print "-----------------------------------------------------------"

print "For tables with string keys instead of indices, it returns nil\n"
for i,v in ipairs(example_table2) do 
  print(i,v) 
end -- => nil output


-- pairs is a built-in iterator function that returns a set of
-- key/value pairs. You can use it much like Ruby's Enumerable#each_with_index
for index,value in pairs(example_table) do
  print((value * 10).." is an order of magnitude more than the number at index " .. index)
end

print "-----------------------------------------------------------"
-- Since functions are closures, a common idiom in Lua is to contstruct
-- iterators as one function called from the body of another.

-- a simple iterator to return the values in a list
function values(n)
  local i = 0
  local foo = function() 
    i= i+1 
    return n[i]
  end
  return foo
end

-- Lua for loops name variables before the "in" and set those variables
-- with a list of expressions after the "in"
print "Simply print values in a list:"
for element in values(example_table) do
  print(element)
end



print "-----------------------------------------------------------"

-- Now we will create a Ruby-style iterator, in which we pass a function to the call.
-- We will ensure that the passed-in function is called for every member of the list
-- in the same way that a block passed to Ruby's Enumerable#each will be executed
-- for each member of an Array/Hash object in Ruby.

function do_and_print_to_each(table, f)
  for value in values(table) do
    print(f(value))
  end
end

print "Running the custom iterator -- get the log of each number"
do_and_print_to_each(example_table, math.log)

print "-----------------------------------------------------------"

print "Running the custom iterator -- use each as a ceiling for generating a random number"
do_and_print_to_each(example_table, math.random)


