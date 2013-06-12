#!/usr/bin/env luma

meta[[

luma.define_simple("mk_power", function (args)
                                   args.pow = {}
                                   for i = 1, tonumber(args[1]) do
                                     table.insert(args.pow, {})
                                   end
                                   return [[function (x)
                                              return $pow[=[x*]=]1
                                            end]]
                                 end)

]]

power3 = mk_power[[3]]

print(power3(2))
print(power3(3))

