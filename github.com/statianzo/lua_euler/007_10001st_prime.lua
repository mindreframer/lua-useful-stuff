function is_prime(n)
  if n <= 1 then return false end
  for i=2, math.sqrt(n) do
    if (math.mod(n, i) == 0) then
      return false
    end
  end
  return true
end

function primes()
  coroutine.yield(2)
  coroutine.yield(3)
  local i = 0
  local candidates = {1, 5}
  while(true) do
    for _,c in ipairs(candidates) do
      local n = i + c
      if is_prime(n) then
        coroutine.yield(n)
      end
    end
    i = i + 6
  end
end

local next_prime = coroutine.wrap(primes)

for i=1, 10000 do
  next_prime()
end

print(next_prime())
