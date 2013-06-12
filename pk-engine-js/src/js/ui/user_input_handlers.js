//------------------------------------------------------------------------------
// user_input_handlers.js: Callbacks handling UI events: mouse, keyboard etc.
// This file is a part of pk-engine-js library
// Copyright (c) Alexander Gladysh <ag@logiceditor.com>
// Copyright (c) Dmitry Potapov <dp@logiceditor.com>
// See file `COPYRIGHT` for the license
//------------------------------------------------------------------------------

PKEngine.UserInputHandlers = new function()
{
  var user_input_provider_;
  var ignore_window_orientation_;

  //----------------------------------------------------------------------------

  //  Core thing, should be moved into pk-core-js later
  var prepare_event_ = function(e)
  {
    if (e === undefined)
    {
      return window.event
    }
    return e
  }

  //  Core thing, should be moved into pk-core-js later
  var prevent_event_ = function(e)
  {
    if(e.preventDefault)
      e.preventDefault()
    else
      e.returnValue = false
  }

  //----------------------------------------------------------------------------

  var input_handling_is_enabled_ = function()
  {
    if (!PKEngine.GUI.Viewport.is_ready())
      return false

    if (additional_input_handling_preventor_)
      return additional_input_handling_preventor_()

    return true
  }

  //----------------------------------------------------------------------------

  var get_coords_shift_ = function()
  {
    return {
      x: (document.body.scrollLeft - user_input_provider_.offsetLeft),
      y: (document.body.scrollTop - user_input_provider_.offsetTop)
    }
  }

  //----------------------------------------------------------------------------

  // Private methods dependent on platform

  var check_integrity_;

  // Must return 'true' if we can process user input now
  var additional_input_handling_preventor_;

  var get_cursor_coords_;

  //----------------------------------------------------------------------------
  // PUBLIC
  //----------------------------------------------------------------------------

  this.init = function(platform_type, game_field, ignore_window_orientation)
  {
    user_input_provider_ = game_field;
    ignore_window_orientation_ = ignore_window_orientation

    switch (platform_type)
    {
      case PKEngine.Platform.TYPE.IPAD:
        get_cursor_coords_ = function(e)
        {
          var coords_shift = get_coords_shift_();
          return {
            x: (e.changedTouches.item(e.changedTouches.length - 1).clientX + coords_shift.x),
            y: (e.changedTouches.item(e.changedTouches.length - 1).clientY + coords_shift.y)
          };
        }

        additional_input_handling_preventor_ = function()
        {
          if (!ignore_window_orientation_ && (window.orientation == 0 || window.orientation == 180))
          {
            return false
          }

          return true
        }

        check_integrity_ = function()
        {
          return (
              user_input_provider_.ontouchstart
              && user_input_provider_.ontouchend
              && user_input_provider_.ontouchmove
            )
        }

        user_input_provider_.ontouchstart = PKEngine.UserInputHandlers.on_mouse_down;
        user_input_provider_.ontouchend = PKEngine.UserInputHandlers.on_mouse_up;
        user_input_provider_.ontouchmove = PKEngine.UserInputHandlers.on_mouse_move;
      break;

      default:
        get_cursor_coords_ = function(e)
        {
          var coords_shift = get_coords_shift_();
          return {
            x: (e.clientX + coords_shift.x),
            y: (e.clientY + coords_shift.y)
          };
        }

        check_integrity_ = function()
        {
          return (
              user_input_provider_.onmousedown
              && user_input_provider_.onmouseup
              && user_input_provider_.onmousemove
            )
        }

        user_input_provider_.onmousedown = PKEngine.UserInputHandlers.on_mouse_down;
        user_input_provider_.onmouseup = PKEngine.UserInputHandlers.on_mouse_up;
        user_input_provider_.onmousemove = PKEngine.UserInputHandlers.on_mouse_move;
    }
  }

  //----------------------------------------------------------------------------

  this.check_integrity = function()
  {
    return !check_integrity_ || check_integrity_()
  }

  //----------------------------------------------------------------------------

  this.on_mouse_down = function(e)
  {
    if(!input_handling_is_enabled_()) return 0;

    PK.Error.handle_error(function()
    {
      e = prepare_event_(e)

      var mouse_coords = get_cursor_coords_(e);

      PKEngine.GUI.Viewport.on_mouse_down(mouse_coords.x, mouse_coords.y)

      prevent_event_(e)
    }, 'PKEngine.UserInputHandlers.on_mouse_down');

    return false;
  }

  //----------------------------------------------------------------------------

  this.on_mouse_up = function(e)
  {
    if(!input_handling_is_enabled_()) return 0;

    PK.Error.handle_error(function()
    {
      e = prepare_event_(e)

      var mouse_coords = get_cursor_coords_(e);

      PKEngine.GUI.Viewport.on_click(mouse_coords.x, mouse_coords.y)

      prevent_event_(e)
    }, 'PKEngine.UserInputHandlers.on_mouse_up');

    return false;
  }

  //----------------------------------------------------------------------------

  this.on_mouse_move = function(e)
  {
    if(!input_handling_is_enabled_()) return 0;

    PK.Error.handle_error(function()
    {
      e = prepare_event_(e)

      var mouse_coords = get_cursor_coords_(e);

      PKEngine.GUI.Viewport.on_mouse_move(mouse_coords.x, mouse_coords.y);

      prevent_event_(e)
    }, 'PKEngine.UserInputHandlers.on_mouse_move');

    return false;
  }
}
