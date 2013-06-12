//------------------------------------------------------------------------------
// draw_text.js: Draw text
// This file is a part of pk-engine-js library
// Copyright (c) Alexander Gladysh <ag@logiceditor.com>
// Copyright (c) Dmitry Potapov <dp@logiceditor.com>
// See file `COPYRIGHT` for the license
//------------------------------------------------------------------------------

var setFontProperties = function(params)
{

  var font_properties = {};
  var game_field_2d_cntx = PKEngine.GUI.Context_2D.get();

  PK.override_object_properties(
      font_properties,
      {
        shadow       : { default_value: false },
        color        : { default_value: 'white' },
        family       : { default_value: 'Arial' },
        size         : { default_value: '20' },
        line_spacing : { default_value: '25' },
        align        : { default_value: 'left' }
      },
      params
    )

  var color
  if (typeof font_properties.color == 'string')
  {
    color = font_properties.color
  }
  else
  {
    color = 'rgba('
      + font_properties.color[0] + ','
      + font_properties.color[1] + ','
      + font_properties.color[2] + ',1)'
  }

  var font_style = font_properties.size + "pt " + font_properties.family

  PKEngine.reset_shadow()

  if (font_properties.shadow == true)
  {
    game_field_2d_cntx.shadowColor = 'rgba(0,0,0,1)';
    game_field_2d_cntx.shadowOffsetX = 2;
    game_field_2d_cntx.shadowOffsetY = 2;
    game_field_2d_cntx.shadowBlur = 4;
  }

  game_field_2d_cntx.fillStyle = color
  game_field_2d_cntx.textAlign = font_properties.align
  game_field_2d_cntx.font = font_style
}

var drawText = function(text, x, y, params)
{
  if(x === undefined || x == "center")
    x = PKEngine.GUIControls.get_center().x
  if(y === undefined || y == "center")
    y = PKEngine.GUIControls.get_center().y

  setFontProperties(params);

  var game_field_2d_cntx = PKEngine.GUI.Context_2D.get();
  var text_lines = text.split("\n")
  game_field_2d_cntx.save()
  game_field_2d_cntx.translate(x, y)
  var line_spacing = (params.line_spacing) ? params.line_spacing : params.size;
  for (var i = 0; i < text_lines.length; i++)
  {
    game_field_2d_cntx.fillText(text_lines[i], 0, i*line_spacing)
  }
  game_field_2d_cntx.restore()

  PKEngine.reset_shadow()
}
