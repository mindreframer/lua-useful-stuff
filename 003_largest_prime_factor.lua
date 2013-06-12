function largest_prime_factor(x, current)
  local current = current or 1

  if x == 1 then return current
  elseif x == 0 then return 0
  end

  for i=2, x do
    if (math.mod(x,i) == 0) then
      local larger = i > current and i or current
      return largest_prime_factor(x/i, larger)
    end
  end
end

print(largest_prime_factor(600851475143))
