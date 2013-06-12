//------------------------------------------------------------------------------
// array.js: Array utils
// This file is a part of pk-core-js library
// Copyright (c) Alexander Gladysh <ag@logiceditor.com>
// Copyright (c) Dmitry Potapov <dp@logiceditor.com>
// See file `COPYRIGHT` for the license
//------------------------------------------------------------------------------

// TODO: Very non-optimal!
PK.remove_holes_in_array = function(arr)
{
  if (!arr || arr.length == 0)
    return

  //PKLILE.timing.start("remove_holes_in_array")
  var i = 0;
  while (i < arr.length)
  {
    if (arr[i] === undefined)
    {
      arr.splice(i, 1)
    }
    else
    {
      i++
    }
  }
  //PKLILE.timing.stop("remove_holes_in_array")
}

PK.is_value_in_array = function(arr, value)
{
  if(arr.constructor.toString().indexOf("Array") == -1)
  {
    return false;
  }

  for(var i = 0; i < arr.length; i++)
  {
    if(arr[i] == value)
    {
      return true;
    }
  }

  return false;
}
