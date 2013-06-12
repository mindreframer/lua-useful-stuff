function is_prime(n)
  if n <= 1 then return false end
  for i=2, math.sqrt(n) do
    if (math.mod(n, i) == 0) then
      return false
    end
  end
  return true
end

function primes(max)
  local p = {}
  table.insert(p,2, true)
  table.insert(p,3, true)
  local i = 0
  local candidates = {1, 5}
  while(true) do
    for _,c in ipairs(candidates) do
      local n = i + c
      if n > max then
        return p
      elseif is_prime(n) then
        table.insert(p,n, true)
      end
    end
    i = i + 6
  end
end

local memo = primes(7000) -- memo of primes
local max = 0
local max_a = 0
local max_b = 0

for b=3,999,2 do
  if memo[b] then -- b is always prime
    for a=-(b),b do -- a > -b and b > a
      local score = 0
      repeat do
        score = score+1
      end until not memo[(a+score)*score+b]
      if score > max then
        max = score
        max_a = a
        max_b = b
      end
    end
  end
end

print(max_a, max_b, max, max_a*max_b)


