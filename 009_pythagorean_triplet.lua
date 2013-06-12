function triplet()
  for a=0, 332 do
    for b=a+1,499 do
      local c = 1000 - a - b
      if a^2 + b^2 == c^2 then
        return a * b*c
      end
    end
  end
end

print(triplet())
