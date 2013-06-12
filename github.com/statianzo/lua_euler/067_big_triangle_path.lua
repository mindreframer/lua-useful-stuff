local triangle = { }
for l in io.lines('067_data.txt') do
  local row = {}
  for n in string.gmatch(l,'%d+') do
    table.insert(row, tonumber(n))
  end
  table.insert(triangle,row)
end

for i=#triangle-1,1,-1 do
  local row = triangle[i]
  local prev = triangle[i+1]
  for j=1, #row do
    row[j] = row[j] + math.max(prev[j], prev[j+1])
  end
end

print(triangle[1][1])
