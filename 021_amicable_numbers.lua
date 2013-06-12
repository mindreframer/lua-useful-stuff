function sum_of_divisors(n)
  local sq = math.sqrt(n)
  local _,frac = math.modf(sq)
  local sum = frac == 0 and sq+1 or 1
  for i=2, sq-1 do
    if math.fmod(n,i) == 0 then
      sum = sum + i + n/i
    end
  end
  return sum
end

local total = 0
for i=3, 9999 do
  local s = sum_of_divisors(i)
  if s ~= i and sum_of_divisors(s) == i then
    total = total + i
  end
end

print(total)
