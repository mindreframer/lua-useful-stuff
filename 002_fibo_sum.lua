function co_fibs()
  local prev1 = 0
  local prev2 = 1
  while(true) do
    local cur = prev1 + prev2
    coroutine.yield(cur)
    prev1, prev2 = cur, prev1
  end
end

local next_fib = coroutine.wrap(co_fibs)

local current = 0
local sum = 0
while(current < 4000000) do
  if math.mod(current,2) == 0 then
    sum = sum + current
  end
  current = next_fib()
end

print(sum)

