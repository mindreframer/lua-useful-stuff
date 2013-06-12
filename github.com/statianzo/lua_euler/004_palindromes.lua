function largest_palindrome()
  local largest = 0
  for i=999, 100, -1 do
    for j=999, 100, -1 do
      local x = i * j
      if (x > largest and tostring(x) == string.reverse(x)) then
        largest = x
      end
    end
  end
  return largest
end

print(largest_palindrome())
