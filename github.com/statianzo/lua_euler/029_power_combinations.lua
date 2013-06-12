local results = {}
for a=2,100 do
  for b=2,100 do
    results[a^b] = true
  end
end

local count = 0
for _,_ in pairs(results) do
  count = count + 1
end

print(count)
