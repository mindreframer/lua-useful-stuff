#!/usr/bin/env lua

s = require("say")

s:set_namespace("en")

s:set('money', 'I have %s dollars')
s:set('wow', 'So much money!')

print(s('money', {1000})) -- I have 1000 dollars

s:set_namespace("fr") -- switch to french!
s:set('money', 'I  have %s Euros! ))')
s:set('wow', "Tant d'argent!")


print(s('wow')) -- Tant d'argent!
print(s('money', {222})) -- So much money!
s:set_namespace("en")  -- switch back to english!
print(s('wow')) -- So much money!
