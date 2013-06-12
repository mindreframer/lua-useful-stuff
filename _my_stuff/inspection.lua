#!/usr/bin/env lua


local inspect = require 'inspect'

function pinspect(a)
  print(inspect(a))
end

polyline = {color="blue", thickness=2, npoints=4,
                  {x=0,   y=0},
                  {x=-10, y=0},
                  {x=-10, y=1},
                  {x=0,   y=1}
}


print(inspect(polyline))
print(polyline[2].y)

opnames = {["+"] = "add", ["-"] = "sub",
                ["*"] = "mul", ["/"] = "div"}
pinspect(opnames)
i = 20; s = "-"
a = {[i+0] = s, [i+1] = s..s, [i+2] = s..s..s}
print(opnames[s])    --> sub
print(a[22])         --> ---


--  want their arrays starting at 0
days = {[0]="Sunday", "Monday", "Tuesday", "Wednesday",
             "Thursday", "Friday", "Saturday"}
pinspect(days)
print(days[6])