-- Lua's notion of object orientation feels a lot like Javascript's, and this is in part due
-- to the fact that they were both created by admirers of a rather obscure language called Self
-- http://en.wikipedia.org/wiki/Self_(programming_language)
--
-- As in Javascript, you create notions of objects by creating an empty container for the state, 
-- attributes and methods and then manipulating that container.  In Javascript, this container is 
-- a Javascript object. In Lua, it is a table.  Coincidentally, the syntax for literal construction 
-- of these is the same in both languages.

-- Let's dig deeper.

-- Lua tables are objects:
OrigAccount = {
  balance = 5000 --this works like an attribute
}

Account = OrigAccount -- let's act on a copy so this script can all execute at once
function Account.withdraw(amt)
  Account.balance = Account.balance - amt
end

Account.withdraw(1000)
print(Account.balance)

-- Look at us defining functions right on an object - just like we can in Ruby!
-- But this is kind of dumb.  We are acting on Account from inside the body of one
-- of its methods.  That violates the OOP principle of objects having independent
-- lifecycles.

-- We can fix this by altering the function to take a parameter representing the receiving object.
-- Passing in "self" means we can re-write the function to avoid operating directly on Account 
-- from inside the function.

function Account.withdraw(self, amt)
  self.balance = self.balance - amt
end

-- This gives us the means to act on a copy of the original object
a1 = Account
Account = nil -- prove we are no longer acting on the original Account object (this is why we need OrigAccount)

a1.withdraw(a1, 1000)
print(a1.balance)

-- We even get a syntactic sugar to help us avoid always having to pass
-- the object into its own method.  The function above can be re-written
-- with the magic colon:

Account = OrigAccount -- reset Account so it's not nil and we can define things on it

function Account:short_withdraw(amt) -- the same as writing "function Account.short_withdraw(self, amt)"
  self.balance = self.balance - amt
end

a1 = Account
Account = nil

a1.short_withdraw(a1, 1000) -- Same as a1:short_withdraw(1000)
print(a1.balance)

-- But this is of limited utility.  We've got an object that we can define
-- state and behavior on, but we have to sort of clone it for use.  What we'd rather
-- have is a template for making lots of similar objects - a "class" in normal OOP parlance.

-- Again we must start with an empty container, to hold the state and functions defining the class 
-- and act as a prototype for instances:
--
-- Every class needs a constructor!
-- warning: the idiom below will tie your brain in knots
OopAccount = {} 
function OopAccount:new(o)
  o = o or {}            -- create object if user does not provide one
  setmetatable(o, self)  -- metatable is *a bit* like an Eigenclass in Ruby
  self.__index = self    --  "__index" metamethod behaves a little bit like Ruby's method_missing
  return o
end

function OopAccount:deposit(amt)
  self.balance = self.balance + amt
end

function OopAccount:goodtimes(place)
  print("Good times can be had at ".. place)
end

a = OopAccount:new({balance = 0})
print(a.balance)
a:deposit(5000000)
print(a.balance)

a:goodtimes("Alice's Restaurant")
a:goodtimes("Austin.rb")
