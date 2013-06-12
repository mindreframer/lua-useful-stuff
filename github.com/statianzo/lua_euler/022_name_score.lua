local name_data = io.input('022_data.txt'):read('*a')
local names = {}
for n in string.gmatch(name_data, '%w+') do
  table.insert(names, n)
end
table.sort(names)

local sum = 0
for i,n in ipairs(names) do
  local bytes = {string.byte(n,1,#n)}
  for _,b in ipairs(bytes) do
    sum = sum + (b-64)*i
  end
end

print(sum)
