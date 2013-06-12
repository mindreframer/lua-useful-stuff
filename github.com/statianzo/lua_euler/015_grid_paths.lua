function factorial(n)
  local result = 1
  for i=2,n do
    result = result * i
  end
  return result
end

--40 choose 20
print(factorial(40)/(factorial(20)^2)
