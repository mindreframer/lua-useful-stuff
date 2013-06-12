package.path  = ''
package.cpath = './?.so'

local markdown = require "ldiscount"

assert(markdown "*It works!*" == "<p><em>It works!</em></p>")
