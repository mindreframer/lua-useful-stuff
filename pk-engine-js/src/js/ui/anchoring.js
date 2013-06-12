//------------------------------------------------------------------------------
// anchoring.js: Calculation of anchoring
// This file is a part of pk-engine-js library
// Copyright (c) Alexander Gladysh <ag@logiceditor.com>
// Copyright (c) Dmitry Potapov <dp@logiceditor.com>
// See file `COPYRIGHT` for the license
//------------------------------------------------------------------------------

PKEngine.Anchoring = new function()
{
  this.calc_tl_corner = function(x, y, anchor_x, anchor_y, width, height)
  {
    if(x === undefined || x == "center")
    {
      // TODO: Note: behaviour differs from what we have for labels
      x = PKEngine.GUIControls.get_center().x - width / 2
    }
    else if (anchor_x == 'center')
    {
      x -= width / 2
    }
    else if (anchor_x == 'right')
    {
      x -= width
    }


    if(y === undefined || y == "center")
    {
      // TODO: Note: behaviour differs from what we have for labels
      y = PKEngine.GUIControls.get_center().y - height / 2
    }
    else if (anchor_y == 'center')
    {
      y -= height / 2
    }
    else if (anchor_y == 'bottom')
    {
      y -= height
    }

    return { x: x, y: y }
  }
}
