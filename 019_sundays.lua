local months = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }

local y = 1901
local m = 1

local dow = 2


local count = 0
while (y < 2001) do
  local delta = months[m]
  if m == 2 and y%4 == 0 and (y%100 > 0 or y == 2000) then
    delta = delta + 1
  end
  dow = (delta + dow) % 7

  m = m + 1
  if m == 13 then
    m = 1
    y = y + 1
  end

  if dow == 0 then
    count = count + 1
  end
end

print (count)
