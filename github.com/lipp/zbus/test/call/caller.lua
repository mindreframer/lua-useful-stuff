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

local failed

for name,arg_array in pairs(arg_arrays) do
   local results = {caller:call('echo',unpack(arg_array))}
   local match = testutils.deepcompare(arg_array,results)
   if not match then
      failed = true
   end
   print('testing',name, match and 'ok' or 'FAILED')
end

if failed then
   print('exiting',1)
   os.exit(1)
end
print('exiting',0)
os.exit(0)
