function squares_sum(n)
  local sum = 0

  for i=1, n do
    sum = sum + i*i
  end

  return sum
end

local sums_squared = ((100*100 - 1 + 100 + 1)/2)^2

print(sums_squared - squares_sum(100))
