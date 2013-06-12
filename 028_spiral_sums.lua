local sum = 1

for i=3,1001,2 do
  sum = sum + 4*i^2 - 6*(i-1)
end

print(sum)
