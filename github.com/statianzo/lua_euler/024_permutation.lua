local a = {0,1,2,3,4,5,6,7,8,9}

for _=1,999999 do
  local k = -1
  local l = -1
  for i=1, #a-1 do
    if a[i]<a[i+1] then
      k=i
    end
  end
  for i=1, #a do
    if a[k]<a[i] then
      l=i
    end
  end

  a[k],a[l] = a[l],a[k]

  for i=1, (10-k)/2 do
    a[k+i],a[10-(i-1)] = a[10-(i-1)], a[k+i]
  end
end
print(table.concat(a,','))

