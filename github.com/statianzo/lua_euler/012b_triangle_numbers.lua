local num = 0
local j = 0
while(true) do
  j = j + 1
  local f = 0
  num = num + j
  for n=1, math.ceil(math.sqrt(num)) do
    if math.mod(num,n) == 0 then
      f = f + 2
    end
  end
  if f > 500 then
    break
  end
end
print(num)
