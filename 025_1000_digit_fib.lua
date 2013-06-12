local prev1 = 0
local prev2 = 1
local folds = 0
local n = 0
while(true) do
  n = n + 1
  local cur = prev1 + prev2
  prev1, prev2 = cur, prev1
  if prev1 > 1e199 then
    prev1 = prev1/1e200
    prev2 = prev2/1e200
    folds = folds + 1

    if folds == 5 then
      print(n, cur)
      break
    end
  end
end
