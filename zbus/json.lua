local cjson = require'cjson'
local unpack = unpack
local assert = assert
local zbus = require'zbus'
local pcall = pcall
local type = type
local tostring = tostring

module('zbus.json')

local encode = cjson.encode
local decode = cjson.decode

local serialize_array = 
  function(...)
    return encode{...}
  end

local unserialize_array = 
  function(s)
    return unpack(decode(s))
  end

local serialize_args = serialize_array
local unserialize_args = unserialize_array

local serialize_result = serialize_array
local unserialize_result = unserialize_array

local serialize_err = 
  function(err)
    if type(err) == 'table' and err.code and err.message then
       return encode(err)       
    else
      local _,msg = pcall(tostring,err) 
      return encode{
        code = -32603,
        message = msg or 'Unknown Error'
      }
    end
  end

local unserialize_err = 
  function(err)
    return decode(err)
  end

local make_err = 
  function(code,msg)
    return encode{
      code = -32603,
      message = 'Internal error',
      data = {
        zerr = {
          code = code,
          message = msg
        }
      }
    }
 end

return {
   make_err = make_err,
   serialize = {
      result = serialize_result,
      args = serialize_args,
      err = serialize_err
   },
   unserialize = {
      result = unserialize_result,
      args = unserialize_args,
      err = unserialize_err
   },
}

