--
--
--
--
--
--  you realize that looking at this early is cheating, right?
--
--
--
--
--
--
--
--  fine.  just as long as you realize.
--
--
--
--
--
--
--
--
--
--
--
--
--
-- A Lua implementation of the credit card check quiz
-- http://www.rubyquiz.com/quiz122.html

CreditCard = {}
CreditCard.card_stats = {
  AMEX = {
    valid_prefixes = {34,37},
    length = 15
  },

  Discover = {
    valid_prefixes = {6011},
    length = 16
  },

  MC = {
    valid_prefixes = {51,52,53,54,55},
    length = 16
  },

  Visa = {
    valid_prefixes = {4},
    length = {13,16}
  }
}

-- Instantiate a CreditCard object with the given number as a string
function CreditCard:new(number)
  assert(type(number) == "string", "Number must be entered as a string")
  local cc = {}
  cc.number = number
  setmetatable(cc, self) 
  self.__index = self
  return cc
end

-- Validate the number against
-- * known number prefix
-- * known number length
-- * Luhn-style checksum
function CreditCard:validate()
  if self:prefix_is_valid()
    and self:size_is_valid()
    and self:checksum_is_valid()
  then
    return true
  else
    return false
  end
end

-- Implement Luhn algorithm for checksum -- http://en.wikipedia.org/wiki/Luhn_algorithm
function CreditCard:checksum_is_valid()
  reversed_number = self.number:reverse()
  temp_array      = {}
  sum             = 0

  for i=1, #reversed_number do
    num = tonumber(reversed_number:sub(i,i))
    if i % 2 == 0 then
      table.insert(temp_array, i, (num * 2))
    else
      table.insert(temp_array, i, num)
    end
  end

  for _,num in pairs(temp_array) do
    sum = sum + num
  end

  return sum % 10 == 0
end

-- Validate size against CreditCard.card_stats
function CreditCard:size_is_valid()
  cc_type         = self:get_type()
  num_length      = self.number:len()
  length_for_type = CreditCard.card_stats[cc_type].length
  
  if cc_type == "Visa" then
    for _,length in ipairs(length_for_type) do
      if length == self.number:len() then
        return true
      end
    end
    return false -- prefix says Visa but size is invalid
  else
    return num_length == length_for_type
  end
end

-- Validate prefix against CreditCard.card_stats
function CreditCard:prefix_is_valid()
  prefix  = self:get_prefix()
  cc_type = self:get_type()
  
  -- There's no equivalent of Array#include?... :-(
  for _, p in pairs(CreditCard.card_stats[cc_type].valid_prefixes) do
    if p == tonumber(prefix) then 
      return true
    end
  end
  return false
end

-- Return the type of the card
function CreditCard:get_type()
  first_digit = self.number:sub(1,1) -- same as string.sub(cc,1,1)
  
  if first_digit == "3" then
    return "Amex"
  elseif first_digit == "4" then
    return "Visa"
  elseif first_digit == "5" then
    return "MC"
  elseif first_digit == "6" then
    return "Discover"
  else
    error("Invalid first digit: "..first_digit)
  end
end

-- Return the prefix of the card
function CreditCard:get_prefix()
  cc_type = self:get_type()
    
  local prefix_size 
  if cc_type == "Discover" then
    prefix_size = 4
  elseif cc_type == "Visa" then
    prefix_size = 1
  else
    prefix_size = 2
  end

  return self.number:sub(1,prefix_size)
end


-- even if you cheated it doesn't really matter.
--
-- it's wrong anyway.  can you find out where?
--
--
---------- USAGE ----------

good_test_number = "5252167810305678"
bad_test_number  = "5491444444444444"

good_card = CreditCard:new(good_test_number)
bad_card  = CreditCard:new(bad_test_number)

print(good_card:validate())
print(bad_card:validate())


