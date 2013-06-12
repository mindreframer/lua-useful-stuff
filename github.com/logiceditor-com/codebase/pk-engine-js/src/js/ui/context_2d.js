//------------------------------------------------------------------------------
// context_2d.js: Canvas 2D context
// This file is a part of pk-engine-js library
// Copyright (c) Alexander Gladysh <ag@logiceditor.com>
// Copyright (c) Dmitry Potapov <dp@logiceditor.com>
// See file `COPYRIGHT` for the license
//------------------------------------------------------------------------------

PKEngine.check_namespace('GUI')

PKEngine.GUI.Context_2D = new function()
{
  this.context_2d = undefined;

  this.init = function(name)
  {
    var game_field = document.getElementById(name),
        canvas_available = false;
    if (typeof G_vmlCanvasManager != 'undefined')  // ie IE
    {
      try
      {
        var flash_version = new ActiveXObject("ShockwaveFlash.ShockwaveFlash")
            .GetVariable("$version").match(/[\d,]+/)[0].replace(/,/g, ".");

        if (parseInt(flash_version) >= 9)
        {
          game_field = G_vmlCanvasManager.initElement(game_field);
          canvas_available = true;
        }
      }
      catch (e) {}
    }
    else if (game_field.getContext)
    {
      canvas_available = true;
    }

    if (!canvas_available)
    {
      var browser_name = " "; // TODO: Fill browser name

      CRITICAL_ERROR(I18N('Your browser ${1} doesnt support HTML5!', browser_name));
      return false;
    }

    this.context_2d = game_field.getContext('2d');
    game_field.width = PKEngine.GUIControls.get_size().width;
    game_field.height = PKEngine.GUIControls.get_size().height;

    return game_field;
  }

  this.get = function()
  {
    return this.context_2d;
  }
}
