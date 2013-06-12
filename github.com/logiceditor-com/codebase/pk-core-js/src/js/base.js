//------------------------------------------------------------------------------
// base.js: Initialize pk core js library
// This file is a part of pk-core-js library
// Copyright (c) Alexander Gladysh <ag@logiceditor.com>
// Copyright (c) Dmitry Potapov <dp@logiceditor.com>
// See file `COPYRIGHT` for the license
//------------------------------------------------------------------------------

if (PK === undefined)
{
  var PK = new function()
  {
    this.check_namespace = function(name)
    {
      if (this[name] === undefined)
        this[name] = new Object
      return this[name]
    }
  }
}
