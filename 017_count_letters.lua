local ones  = {3, 3, 5, 4, 4, 3, 5, 5, 4, [0]=0}
local tens  = {0, 6, 6, 5, 5, 5, 7, 6, 6, [0]=0}
local teens = {6, 6, 8, 8, 7, 7, 9, 8, 8, [0]=3}

function digits(val)
  local g = string.gmatch(string.reverse(val),'%d')
  return tonumber(g()), tonumber(g() or 0),tonumber(g() or 0)
end

local total = 11 --'one thousand'
for i=1, 999 do
  local o, t, h = digits(i)

  if h > 0 then
    total = total + ones[h] + 7 + (t+o > 0 and 3 or 0)
  end

  if t == 1 then
    total = total + teens[o]
  else
    total = total + tens[t] + ones[o]
  end
end

print(total)
