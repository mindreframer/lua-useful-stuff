//------------------------------------------------------------------------------
// draw_helper.js: Functions useful for drawing on canvas
// This file is a part of pk-engine-js library
// Copyright (c) Alexander Gladysh <ag@logiceditor.com>
// Copyright (c) Dmitry Potapov <dp@logiceditor.com>
// See file `COPYRIGHT` for the license
//------------------------------------------------------------------------------

var getContextProperties = function(properties)
{
  if (!properties || !properties.length)
    return

  var old_values = {};
  var game_field_2d_cntx = PKEngine.GUI.Context_2D.get();

  for(var i = 0; i < properties.length; i++)
    old_values[properties[i]] = game_field_2d_cntx[properties[i]]

  return old_values
}

//------------------------------------------------------------------------------

var changeContextProperties = function(properties)
{
  var old_values = {};
  var game_field_2d_cntx = PKEngine.GUI.Context_2D.get();

  for(var name in properties)
  {
    old_values[name] = game_field_2d_cntx[name]
    game_field_2d_cntx[name] = properties[name]
  }

  return old_values
}

//------------------------------------------------------------------------------

PKEngine.reset_shadow = function()
{
  var game_field_2d_cntx = PKEngine.GUI.Context_2D.get();
  game_field_2d_cntx.strokeStyle = 'rgba(0,0,0,0)';
  game_field_2d_cntx.shadowColor = 'rgba(0,0,0,0)';
  game_field_2d_cntx.shadowOffsetX = 0;
  game_field_2d_cntx.shadowOffsetY = 0;
  game_field_2d_cntx.shadowBlur = 0;
}
