function is_abundant(n)
  if n < 12 then return false end
  local sq = math.sqrt(n)
  local floor,frac = math.modf(sq)
  local sum = frac == 0 and sq+1 or 1
  for i=2, frac > 0 and floor or floor-1 do
    if math.fmod(n,i) == 0 then
      sum = sum + i + n/i
    end
  end

  return sum > n
end

local abundants = {}
for i=12,20161 do
  if is_abundant(i) then
    abundants[i] = true
  end
end

local sum = 0
for i=1,20161 do
  local mod = math.fmod(i,2)
  if mod == 1 or i <= 746 then
    local add = i
    for a,_ in pairs(abundants) do
      if abundants[i-a] then
        add = 0
        break
      end
    end
    sum = sum + add
  end
end

print(sum)
