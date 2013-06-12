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

function triangles()
  local i = 1
  local current = 0
  while(true) do
    current = current + i
    coroutine.yield(current)
    i = i + 1
  end
end

local next_prime = coroutine.wrap(primes)

local primes = {}
for  i=0, 10000 do
  table.insert(primes,next_prime())
end

function prime_factors(n)
  local factors = {}
  local x = n
  while(x > 1) do
    for _,p in ipairs(primes) do
      if math.mod(x,p) == 0 then
        table.insert(factors,p)
        x = x/p
      end
    end
  end
  table.sort(factors)
  return factors
end

function factorial(n)
  local result = 1
  for i=2, n do
    result = result * i
  end
  return result
end

function factors_count(factors)
  local count = 1
  local current = 1
  local multiplicity = 0
  for _,f in ipairs(factors) do
    if (f ~= current) then
      count = count * (multiplicity+1)
      multiplicity = 1
      current = f
    else
      multiplicity = multiplicity + 1
    end
  end
  count = count * (multiplicity+1)
  return count
end

local next_triangle = coroutine.wrap(triangles)

local cur = 0
local cur_count = 0
while(cur_count <= 500) do
  cur = next_triangle()
  cur_count = factors_count(prime_factors(cur))
end

print(cur)
