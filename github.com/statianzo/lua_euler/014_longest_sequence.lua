local max = 0
local max_i = 0
--every even has a mirror on the other side of 500k
for i=999999, 500000, -2 do
  local cur = 0
  local j = i
  while (j > 1) do
    if math.fmod(j,2) == 0 then
      j = j / 2
    else
      j = j * 3 + 1
    end
    cur = cur+1
  end
  max_i = cur > max and i or max_i
  max = cur > max and cur or max
end

print(string.format('start:%d length:%d', max_i, max))
