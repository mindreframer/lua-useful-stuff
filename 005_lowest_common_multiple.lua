local lcm = 1
for i=1, 20 do
  if math.mod(lcm, i) > 0 then
    for j=1, 20 do
      if math.mod((lcm*j), i) == 0 then
        lcm = lcm * j
        break
      end
    end
  end
end

print(lcm)
