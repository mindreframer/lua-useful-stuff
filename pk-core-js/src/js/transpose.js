//------------------------------------------------------------------------------
// transpose.js: Transpose a multi-dimensional array
// This file is a part of pk-core-js library
// Copyright (c) Alexander Gladysh <ag@logiceditor.com>
// Copyright (c) Dmitry Potapov <dp@logiceditor.com>
// See file `COPYRIGHT` for the license
//------------------------------------------------------------------------------

/**
 * Method to transpose a multi-dimensional array
 */
Array.prototype.transpose = function() {
  var result = [];

  if (!(this instanceof Array))
  {
    return result;
  }
  if (this.length == 0)
  {
    return result;
  }
  if (!(this[0] instanceof Array))
  {
    return result;
  }
  if (this[0].length == 0)
  {
    return result;
  }

  for(var i = 0; i < this[0].length; i++)
  {
    var row = [];
    for(var n = 0; n < this.length; n++)
    {
      row[n] = this[n][i];
    }
    result[i] = row;
  }

  return result;
};

/**
 * JQuery plugin definition
 */
if(typeof(jQuery) !== "undefined")
{
  jQuery.transpose = function (arr)
  {
    if(arr instanceof Array)
    {
      return arr.transpose();
    }
  };
}
