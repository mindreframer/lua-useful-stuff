local config = require'zbus.json'
local caller = require'zbus.member'.new(config)
local testutils = require'zbus.testutils'

local arg_arrays = {
   single_number = {1},
   single_string = {'hallo'},
   single_bool_1 = {false},
   single_bool_2 = {true},   
   single_object = {
      {
         a = 0.123,
         b = 'text',
         c = true,
         d = false,
         e = {
            aa = 'sub',
            bb = {
               aaa = 'subsub'
            }
         }
      }
   },
   multi_mixed = {1,2,'hallo',false,true,{a = 3}}
}

local counter = 0
local failed

local ticker = ev.Timer.new(
   function()
      counter = counter + 1
      if counter > 1000 then
         ev.Loop.default:unloop()
      end
      for name,arg_array in pairs(arg_arrays) do
         local results = {caller:call('echo',unpack(arg_array))}
         local match = testutils.deepcompare(arg_array,results)
         local n = math.random(1,100000000)
         local nr = caller:call('echo',n)
         if not match or n~= nr then
            print(match,n,nr)
            failed = true
         end
      end
   end,0.01,0.01
)

ticker:start(ev.Loop.default)
ev.Loop.default:loop()

if failed then
   print('ERROR')
   os.exit(1)
end
print('OK')
os.exit(0)
