function multiples_sum(x, max)
  local sum = 0
  for i=x, max, x  do
      sum = sum + i
  end
  return sum
end

local five = multiples_sum(5, 1000)
local three = multiples_sum(3, 1000)
local fifteen = multiples_sum(15, 1000)

print(five + three - fifteen)
