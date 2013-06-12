#!/usr/bin/env lua
-- NameToInstr = {
--   John   = "rhythm guitar",
--   Paul   = "bass guitar",
--   George = "lead guitar",
--   Ringo  = "drumkit"
-- }

-- print(NameToInstr.Ringo)


-- for Name, Instr in pairs(NameToInstr) do
--   print(Name .. " -> " .. Instr)
-- end


function Average(...)
  local Ret, Count = 0, 0
  for _, Num in ipairs({...}) do
    Ret = Ret + Num
    Count = Count + 1
  end

  assert(Count > 0, "no zero args")
  return Ret/Count
end

print(Average(1))

function MakePrinter(...)
  local Args = {...}
  return function()
    print(unpack(Args))
  end
end

Printer = MakePrinter("a", "b", "c")
Printer()

local me = {
  fullname = function(self)
    return self.first_name .. " " .. self.last_name
  end
}
me.first_name = "Roman"
me.last_name  = "Heinrich"
print(me:fullname())