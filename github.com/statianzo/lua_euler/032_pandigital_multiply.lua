local products = {}

function is_pandigital(n)
  if #n ~= 9 then
    return false
  end

  for i=1,9 do
    if not string.match(n,i) then
      return false
    end
  end

  return true
end

for i=1, 99 do
  if i%10 == 0 then
    i=i+1
  end
  local start,stop = 1234, 9876
  if i > 10 then
    start,stop = 123,987
  end

  for j=start,stop do
    v = i*j
    if is_pandigital(i .. j .. v) then
      print(i,j,v)
      products[v] = true
    end
  end
end

local sum = 0
for k,_ in pairs(products) do
  sum = sum + k
end

print(sum)
