-- Lua functions are first-class citizens
-- and feel sorta like Javascript functions


-- A regular old function in the global namespace
function say_something(msg)
  print(msg)
end
say_something("Lua is lovely")


-- Functions can be named members of tables -- just define them 
-- at an arbitrary index with dot notation like anything else
Object = {}
function Object.jump(amount)
  return amount + 100
end
print(Object.jump(50))


-- You can assign an anonymous function to a variable (not that useful on its own)
other_jump = function(amount)
  return amount + 25
end
print(other_jump(5))


-- Functions can be passed assigned to variables and passed around like in Javascript
object_jump = Object.jump
Object.jump = nil
print(object_jump(222))


-- Functions can be defined in table literals like in Javascript.
-- This functionality provides the basis for doing prototypal inheritance.
MagicTable = {
  talk_magix = function (n)
    print("Magix is "..n)
  end

}
MagicTable.talk_magix("sooper fun")


