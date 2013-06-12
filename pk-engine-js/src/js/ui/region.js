//------------------------------------------------------------------------------
// region.js: Region class (a set of rectangles actually)
// This file is a part of pk-engine-js library
// Copyright (c) Alexander Gladysh <ag@logiceditor.com>
// Copyright (c) Dmitry Potapov <dp@logiceditor.com>
// See file `COPYRIGHT` for the license
//------------------------------------------------------------------------------

PKEngine.check_namespace('GUI')

PKEngine.GUI.Region = new function()
{

this.make = function() { return new function()
{
  var rectangles_ = []

  this.clear = function()
  {
    rectangles_ = []
  }

  this.add_rect = function(x1_or_rect, y1, x2, y2)
  {
    if (y1 === undefined && x2 === undefined && y2 === undefined)
      rectangles_.push(PK.clone(x1_or_rect))
    else
      rectangles_.push({ left: x1_or_rect, top: y1, right: x2, bottom: y2})
  }

  this.add_region = function(region)
  {
    var rectangles = region.get_rects()
    for (var i = 0; i < rectangles.length; i++ )
      rectangles_.push(PK.clone(rectangles[i]))
  }

  this.is_empty = function()
  {
    return rectangles_.length == 0
  }

  this.get_rects = function()
  {
    return PK.clone(rectangles_)
  }

}}

}
