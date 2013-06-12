//------------------------------------------------------------------------------
// browser_dom.js: Dom functions
// This file is a part of pk-core-js library
// Copyright (c) Alexander Gladysh <ag@logiceditor.com>
// Copyright (c) Dmitry Potapov <dp@logiceditor.com>
// See file `COPYRIGHT` for the license
//------------------------------------------------------------------------------

PK.browser_dom = new function()
{
  var id_prefix = "pk_"

  var last_id_ = 0
  var MAX_ID_VALUE = Number.MAX_VALUE

  this.reset_id_generation = function()
  {
    last_id_ = 0
  }

  this.generated_id = function()
  {
    if (last_id_ === MAX_ID_VALUE)
    {
      LOG("Warning: PK.browser_dom.last_id_ was reset")
      this.reset_id_generation()
    }

    return id_prefix + (++last_id_)
  }

  this.get_object_by_id = function(id)
  {
    if (document.getElementById)
      return document.getElementById(id)
    assert(false, "document.getElementById() not supported!")
    return undefined
  }

  this.get_obj_position = function(obj)
  {
    var topValue = 0, leftValue = 0
    while(obj)
    {
      leftValue += obj.offsetLeft
      topValue += obj.offsetTop
      obj = obj.offsetParent
    }
    return [leftValue,topValue]
  }

  //----------------------------------------------------------------------------

  this.get_mouse_position = function()
  {
    var posx = 0, posy = 0, e = window.event;

    if (e.pageX || e.pageY)
    {
      posx = e.pageX
      posy = e.pageY
    }
    else if (e.clientX || e.clientY)
    {
      posx = e.clientX + document.body.scrollLeft
        + document.documentElement.scrollLeft
      posy = e.clientY + document.body.scrollTop
        + document.documentElement.scrollTop
    }
    return [posx, posy]
  }
}
