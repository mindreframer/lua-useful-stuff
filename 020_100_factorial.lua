local digits = {1}

for i=1, 100 do
  local result = {}
  for n, x in ipairs(digits) do
    local m = i * x
    local k = n
    for d in string.gmatch(string.reverse(tostring(m)), '%d') do
      result[k] = tonumber(d) + (result[k] or 0)
      k = k + 1
    end
  end
  for n,x in ipairs(result) do
    if x >= 10 then
      result[n] = math.fmod(x,10)
      result[n+1] = math.floor(x/10) + (result[n+1] or 0)
    end
  end
  digits=result
end

local sum = 0
for _,d in ipairs(digits) do
  sum = sum + d
end
print(sum)
