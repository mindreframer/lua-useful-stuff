//------------------------------------------------------------------------------
// label.js: Label
// This file is a part of pk-engine-js library
// Copyright (c) Alexander Gladysh <ag@logiceditor.com>
// Copyright (c) Dmitry Potapov <dp@logiceditor.com>
// See file `COPYRIGHT` for the license
//------------------------------------------------------------------------------

PKEngine.Label = PKEngine.Control.extend(
{
  width: 0,
  height: 0,
  clickable: false,
  text: '',
  params: undefined,

  init: function(x, y, width, height, clickable, text, params)
  {
    this.x = x;
    this.y = y;
    this.width = width;
    this.height = height;
    this.clickable = clickable;
    this.text = text;
    this.params = params;
  },

  set_text: function(text)
  {
    this.text = text;
  },

  set_params: function(params)
  {
    PK.override_object_properties(
        this.params,
        { shadow : {}, color : {}, family : {}, size : {}, align : {} },
        params
    );
  },

  on_click: function(x, y)
  {
    return this.is_on_control_(x, y);
  },

  is_on_control_: function(x, y)
  {
    if(!this.enabled|| !this.clickable || !this.width || !this.height)
      return false

    var label_x = this.x;
    var label_y = this.y;

    if (this.params.align == "center")
    {
      label_x -= this.width / 2;
    }
    else if (this.params.align == "right")
    {
      label_x -= this.width;
    }

    // Note: Only bottom Y-alignment of text is allowed now
    label_y -= this.height;

    return (
        y >= label_y && y <= (label_y + this.height) &&
        x >= label_x && x <= (label_x + this.width)
    )
  },

  draw: function()
  {
    PKEngine.GUI.Viewport.notify_control_draw_start()

    if (!this.visible)
    {
      return;
    }

    drawText(this.text, this.x, this.y, this.params);
  }
})
