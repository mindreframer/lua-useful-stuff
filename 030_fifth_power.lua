local digits = {[0]=0, 1, 32, 243, 1024, 3125, 7776, 16807, 32768, 59049}

local sum = 0
for i=2, 295245 do
  --unwrapped loop for ~100ms gain
  local score = i -
    digits[i%10] -
    digits[math.floor(i/10%10)] -
    digits[math.floor(i/100%10)] -
    digits[math.floor(i/1000%10)] -
    digits[math.floor(i/10000%10)] -
    digits[math.floor(i/100000%10)]
    sum = score == 0 and sum + i or sum
end

print(sum)


