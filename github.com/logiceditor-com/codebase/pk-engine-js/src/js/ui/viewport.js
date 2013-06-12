//------------------------------------------------------------------------------
// viewport.js: Viewport container
// This file is a part of pk-engine-js library
// Copyright (c) Alexander Gladysh <ag@logiceditor.com>
// Copyright (c) Dmitry Potapov <dp@logiceditor.com>
// See file `COPYRIGHT` for the license
//------------------------------------------------------------------------------

PKEngine.check_namespace('GUI')

/**
 * Viewport object
 */
PKEngine.GUI.Viewport = new function()
{
  // NOTE: first element - last viewed screen
  //       list type - [{'screen':screen_name, 'params':param_1}, ...]
  var screens_list_ = [];
  var game_field_id_ = "game_field";
  var loader_id_ = "div_loader";
  var previous_screen_additional_checks_ = undefined;

  var MAX_SCREENS_LIST_LENGTH = 10;

  var is_drawing_;
  var must_redraw_;

  var instance_ = this;

  //----------------------------------------------------------------------------

  var show_screen_ = function(screen, param_1)
  {
    PKEngine.GUIControls.get_screen(screen).show(param_1)
    instance_.request_redraw(screen, param_1)
  }

  //----------------------------------------------------------------------------

  this.init = function (game_field_id, loader_id, previous_screen_additional_checks)
  {
    game_field_id_ = game_field_id;
    loader_id_ = loader_id;
    previous_screen_additional_checks_ = previous_screen_additional_checks;
  }

  this.is_ready = function()
  {
    return !!this.get_current_screen()
  }

  this.get_current_screen = function()
  {
    if (screens_list_.length == 0)
      return false

    return screens_list_[0].screen
  }

  this.get_current_screen_data = function()
  {
    if (screens_list_.length == 0)
      return false

    return screens_list_[0]
  }

  //----------------------------------------------------------------------------

  this.get_previous_screen = function()
  {
    if (screens_list_.length < 2)
      return false

    return screens_list_[1].screen
  }

  //----------------------------------------------------------------------------

  this.return_to_previous_screen = function(do_additional_checks)
  {
    if (do_additional_checks === undefined) { do_additional_checks = true }

    //console.log(
    //    "[PKEngine.GUIControls.Viewport.return_to_previous_screen]",
    //    do_additional_checks, this.get_current_screen_data(), this.get_previous_screen()
    //  )

    if (do_additional_checks && previous_screen_additional_checks_)
    {
      var need_continue = previous_screen_additional_checks_();
      if (!need_continue) return;
    }

    screens_list_.shift()
    var screen_data = this.get_current_screen_data()
    show_screen_(screen_data.screen, screen_data.params)
  }

  this.shift_screens_list = function ()
  {
    return screens_list_.shift();
  }

  //----------------------------------------------------------------------------

  this.show_screen = function(screen, param_1)
  {
    //console.log("[PKEngine.GUIControls.Viewport.show_screen]", screen)

    screens_list_.unshift({'screen':screen, 'params':param_1})

    if (screens_list_.length > MAX_SCREENS_LIST_LENGTH)
      for (var i=0; i<(screens_list_.length - MAX_SCREENS_LIST_LENGTH); i++)
        screens_list_.pop()

    show_screen_(screen, param_1)

    //console.log("screen:", screen)
    //console.log(window.printStackTrace().join("\n"))
  }

  //----------------------------------------------------------------------------

  this.request_redraw = function(notify_current_screen_if_possible)
  {
    //console.log("[PKEngine.GUIControls.Viewport.request_redraw]", notify_current_screen_if_possible)

    if(must_redraw_)
      return

    if (notify_current_screen_if_possible === undefined)
    {
      notify_current_screen_if_possible = true
    }

    must_redraw_ = true

    if (this.is_ready() && notify_current_screen_if_possible)
    {
      var current_screen = PKEngine.GUIControls.get_screen(this.get_current_screen())
      if (current_screen && current_screen.request_redraw)
        current_screen.request_redraw()
    }
  }

  //----------------------------------------------------------------------------

  this.is_drawing = function()
  {
    return is_drawing_
  }

  this.notify_control_draw_start = function()
  {
    assert(is_drawing_, I18N("Viewport: Tried to draw control outside of draw"))
  }

  //----------------------------------------------------------------------------

  this.draw = function()
  {
    if(!this.is_ready())
      return false

    assert(!is_drawing_, I18N("Viewport: Tried to call draw recursively"))

    if (!must_redraw_)
      return

    //console.log("[PKEngine.GUI.Viewport.draw]")

    must_redraw_ = false

    is_drawing_ = true

    PKEngine.GUIControls.get_screen(this.get_current_screen()).draw()

    is_drawing_ = false
  }

  //----------------------------------------------------------------------------

  this.on_mouse_down = function(x, y)
  {
    if(!this.is_ready())
      return false

    PKEngine.GUIControls.get_screen(this.get_current_screen()).on_mouse_down(x, y)
  }

  this.on_click = function(x, y)
  {
    if(!this.is_ready())
      return false

    PKEngine.GUIControls.get_screen(this.get_current_screen()).on_click(x, y)
  }

  this.on_mouse_move = function(x, y)
  {
    if(!this.is_ready())
      return false

    PKEngine.GUIControls.get_screen(this.get_current_screen()).on_mouse_move(x, y)
  }

  //----------------------------------------------------------------------------

  this.show_game_field = function()
  {
    $('#' + loader_id_).hide();
    $('#' + game_field_id_).show();
  }

  this.hide_game_field = function()
  {
    $('#' + loader_id_).hide();
    $('#' + game_field_id_).hide();
  }
}
